#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.parse
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler

CONFIG_DIR = os.path.expanduser("~/.config/illogical-impulse")
GAUTH_FILE = os.path.join(CONFIG_DIR, "gauth.json")
TODO_FILE = os.path.expanduser("~/.local/state/quickshell/user/todo.json")
CALENDAR_FILE = os.path.expanduser("~/.local/state/quickshell/user/calendar_events.json")

DEFAULT_CLIENT_ID = ""
DEFAULT_CLIENT_SECRET = ""
REDIRECT_URI = "http://localhost:8080"
SCOPES = [
    "https://www.googleapis.com/auth/tasks",
    "https://www.googleapis.com/auth/calendar.readonly"
]

def load_auth():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    if os.path.exists(GAUTH_FILE):
        try:
            with open(GAUTH_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "client_id": DEFAULT_CLIENT_ID,
        "client_secret": DEFAULT_CLIENT_SECRET,
        "access_token": "",
        "refresh_token": ""
    }

def save_auth(data):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(GAUTH_FILE, "w") as f:
        json.dump(data, f, indent=2)

class OAuthCallbackHandler(BaseHTTPRequestHandler):
    code = None
    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        if "code" in params:
            OAuthCallbackHandler.code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.end_headers()
            html = """
            <html>
            <head><title>Google Sync Connected</title></head>
            <body style="font-family: sans-serif; background: #121212; color: #e0e0e0; text-align: center; padding-top: 50px;">
                <h1 style="color: #8ab4f8;">¡Conexión Exitosa con Google!</h1>
                <p>Quickshell se ha conectado a tu cuenta de Google Tasks y Calendar.</p>
                <p>Puedes cerrar esta ventana y regresar a tu escritorio.</p>
            </body>
            </html>
            """
            self.wfile.write(html.encode("utf-8"))
        else:
            self.send_response(400)
            self.end_headers()

    def log_message(self, format, *args):
        pass

def login():
    auth = load_auth()
    client_id = auth.get("client_id", DEFAULT_CLIENT_ID)
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent"
    })

    print(f"[GoogleSync] Opening browser for authentication...")
    webbrowser.open(auth_url)

    server = HTTPServer(("localhost", 8080), OAuthCallbackHandler)
    server.handle_request()

    code = OAuthCallbackHandler.code
    if not code:
        print("[GoogleSync] Error: No code received.")
        sys.exit(1)

    # Exchange code for tokens
    client_secret = auth.get("client_secret", DEFAULT_CLIENT_SECRET)
    token_url = "https://oauth2.googleapis.com/token"
    payload = urllib.parse.urlencode({
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code"
    }).encode("utf-8")

    req = urllib.request.Request(token_url, data=payload, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as resp:
            tokens = json.loads(resp.read().decode("utf-8"))
            auth["access_token"] = tokens.get("access_token", "")
            auth["refresh_token"] = tokens.get("refresh_token", auth.get("refresh_token", ""))
            save_auth(auth)
            print("[GoogleSync] Successfully logged in and saved refresh token!")
            sync_all()
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if hasattr(e, "read") else str(e)
        print(f"[GoogleSync] Error exchanging code for tokens (HTTP {e.code}): {error_body}")
        sys.exit(1)
    except Exception as e:
        print(f"[GoogleSync] Error exchanging code for tokens: {e}")
        sys.exit(1)

def get_valid_access_token(auth):
    client_id = auth.get("client_id", DEFAULT_CLIENT_ID)
    client_secret = auth.get("client_secret", DEFAULT_CLIENT_SECRET)
    refresh_token = auth.get("refresh_token", "")

    if not refresh_token:
        print("[GoogleSync] Not logged in (no refresh token).")
        return None

    token_url = "https://oauth2.googleapis.com/token"
    payload = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }).encode("utf-8")

    req = urllib.request.Request(token_url, data=payload, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as resp:
            res = json.loads(resp.read().decode("utf-8"))
            access_token = res.get("access_token", "")
            auth["access_token"] = access_token
            save_auth(auth)
            return access_token
    except Exception as e:
        print(f"[GoogleSync] Token refresh error: {e}")
        return None

def api_request(url, access_token, method="GET", body=None):
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            if not raw:
                return {}
            content = raw.decode("utf-8").strip()
            if not content:
                return {}
            return json.loads(content)
    except Exception as e:
        print(f"[GoogleSync] API request error ({url}): {e}")
        return None

def sync_tasks():
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token:
        return

    # Fetch default task list
    res = api_request("https://tasks.googleapis.com/tasks/v1/lists/@default/tasks?showCompleted=true&showHidden=true", token)
    if not res or "items" not in res:
        print("[GoogleSync] No tasks returned or error.")
        return

    g_tasks = res.get("items", [])
    todo_items = []
    for t in g_tasks:
        title = t.get("title", "").strip()
        if not title:
            continue
        status = t.get("status", "") == "completed"
        todo_items.append({
            "content": title,
            "done": status,
            "gtask_id": t.get("id", "")
        })

    os.makedirs(os.path.dirname(TODO_FILE), exist_ok=True)
    with open(TODO_FILE, "w") as f:
        json.dump(todo_items, f, indent=2)

    print(f"[GoogleSync] Synced {len(todo_items)} tasks from Google Tasks!")

def add_task(title):
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token:
        return
    body = {"title": title}
    api_request("https://tasks.googleapis.com/tasks/v1/lists/@default/tasks", token, method="POST", body=body)
    sync_tasks()

def update_task_status(task_id, done):
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token or not task_id:
        return
    status = "completed" if done else "needsAction"
    body = {"status": status}
    api_request(f"https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/{task_id}", token, method="PATCH", body=body)
    sync_tasks()

def delete_task(task_id):
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token or not task_id:
        return
    api_request(f"https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/{task_id}", token, method="DELETE")
    sync_tasks()

def sync_calendar():
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token:
        return

    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin={urllib.parse.quote(now)}&maxResults=25&singleEvents=true&orderBy=startTime"
    res = api_request(url, token)
    if not res or "items" not in res:
        return

    events = []
    for item in res.get("items", []):
        start = item.get("start", {}).get("dateTime") or item.get("start", {}).get("date")
        summary = item.get("summary", "Sin título")
        events.append({
            "summary": summary,
            "start": start,
            "location": item.get("location", ""),
            "htmlLink": item.get("htmlLink", "")
        })

    os.makedirs(os.path.dirname(CALENDAR_FILE), exist_ok=True)
    with open(CALENDAR_FILE, "w") as f:
        json.dump(events, f, indent=2)

    print(f"[GoogleSync] Synced {len(events)} calendar events!")

def sync_all():
    sync_tasks()
    sync_calendar()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        cmd = "sync"
    else:
        cmd = sys.argv[1]

    if cmd == "login":
        login()
    elif cmd == "sync":
        sync_all()
    elif cmd == "add-task":
        if len(sys.argv) > 2:
            add_task(" ".join(sys.argv[2:]))
    elif cmd == "update-task":
        if len(sys.argv) > 3:
            update_task_status(sys.argv[2], sys.argv[3].lower() == "true")
    elif cmd == "delete-task":
        if len(sys.argv) > 2:
            delete_task(sys.argv[2])
    else:
        sync_all()

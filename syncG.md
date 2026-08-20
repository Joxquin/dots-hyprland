# Google Tasks and Google Calendar Synchronization Setup

This guide explains how to obtain your Google OAuth 2.0 credentials (`Client ID` and `Client Secret`) to enable synchronization for Google Tasks and Google Calendar in Quickshell.

---

## 1. Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Log in with your Google account.
3. Click the project dropdown in the top-left corner and click **New Project**.
4. Enter a project name (for example, `Quickshell Sync`) and click **Create**.
5. Ensure your new project is selected from the top dropdown menu.

---

## 2. Enable Required APIs

1. In the left navigation menu, go to **APIs & Services** > **Library**.
2. Search for **Google Tasks API**, select it, and click **Enable**.
3. Return to the Library, search for **Google Calendar API**, select it, and click **Enable**.

---

## 3. Configure the OAuth Consent Screen

1. In the left navigation menu, go to **APIs & Services** > **OAuth consent screen**.
2. Select **External** as the User Type and click **Create**.
3. Fill in the required fields:
   - **App name**: `Quickshell` (or any preferred name).
   - **User support email**: Select your email address.
   - **Developer contact information**: Enter your email address.
4. Click **Save and Continue**.
5. On the **Scopes** page, click **Add or Remove Scopes** and add the following scopes:
   - `https://www.googleapis.com/auth/tasks`
   - `https://www.googleapis.com/auth/calendar.events`
   - `https://www.googleapis.com/auth/calendar`
6. Click **Update** and then **Save and Continue**.
7. On the **Test users** page, click **Add Users**, enter your Google email address, and save.
8. Click **Save and Continue** until you return to the dashboard.

---

## 4. Create OAuth 2.0 Client Credentials

1. In the left navigation menu, go to **APIs & Services** > **Credentials**.
2. Click **+ Create Credentials** at the top and choose **OAuth client ID**.
3. In the **Application type** dropdown, select **Desktop app**.
4. Enter a name (for example, `Quickshell Desktop Client`).
5. Click **Create**.
6. A dialog will appear displaying your **Client ID** and **Client Secret**. Copy both values.

---

## 5. Configure in Quickshell

1. Open Quickshell Settings (`Super + I` or click the settings icon in the right sidebar).
2. Go to the **Quick** (or **Rapido**) tab.
3. Scroll to the **Google Account Synchronization** section.
4. Paste your **Client ID** and **Client Secret** into their respective fields.
5. Click **Connect Google Account**.
6. Your default web browser will open asking you to sign in and grant permissions.
7. Confirm access. Once approved, the local authentication server will save the tokens to `~/.config/illogical-impulse/gauth.json`.

Synchronization is now active. Your tasks and calendar events will sync automatically and can also be refreshed manually from the interface.

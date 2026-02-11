import { initializeApp } from "firebase/app";
import {
  getAuth,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
  OAuthProvider,
} from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyDcFIknMUwHe2Y6GWSgfC2KxFtQqi7i-lI",
  authDomain: "com-nybroans-vinslipp.firebaseapp.com",
  projectId: "com-nybroans-vinslipp",
  storageBucket: "com-nybroans-vinslipp.firebasestorage.app",
  messagingSenderId: "579199660160",
  appId: "1:579199660160:web:c86dc972e68840a541b665",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

export type AuthUser = { uid: string; displayName: string | null };

export function isNativeApp(): boolean {
  return !!(window as unknown as { webkit?: { messageHandlers?: { appleSignIn?: unknown } } })
    .webkit?.messageHandlers?.appleSignIn;
}

export async function signInWithApple(): Promise<void> {
  if (isNativeApp()) {
    (window as unknown as { webkit: { messageHandlers: { appleSignIn: { postMessage: (msg: unknown) => void } } } })
      .webkit.messageHandlers.appleSignIn.postMessage({});
    return;
  }
  const provider = new OAuthProvider("apple.com");
  provider.addScope("name");
  await signInWithPopup(auth, provider);
}

export async function signOutUser(): Promise<void> {
  if (isNativeApp()) {
    (window as unknown as { webkit: { messageHandlers: { appleSignOut: { postMessage: (msg: unknown) => void } } } })
      .webkit.messageHandlers.appleSignOut.postMessage({});
    return;
  }
  await signOut(auth);
}

export function setNotificationPreference(topic: string): void {
  if (!isNativeApp()) return;
  (window as unknown as { webkit: { messageHandlers: { setNotificationPreference: { postMessage: (msg: unknown) => void } } } })
    .webkit.messageHandlers.setNotificationPreference.postMessage({ topic });
}

export function getNotificationPreference(callback: (topic: string) => void): () => void {
  (window as unknown as { __notificationPreferenceCallback?: (t: string) => void }).__notificationPreferenceCallback = callback;
  if (isNativeApp()) {
    (window as unknown as { webkit: { messageHandlers: { getNotificationPreference: { postMessage: (msg: unknown) => void } } } })
      .webkit.messageHandlers.getNotificationPreference.postMessage({});
  }
  return () => {
    delete (window as unknown as { __notificationPreferenceCallback?: unknown }).__notificationPreferenceCallback;
  };
}

export function onAuthChange(
  callback: (user: AuthUser | null) => void
): () => void {
  const native = isNativeApp();

  // In native app, auth is managed by iOS SDK via JS bridge — skip web SDK listener
  // (web SDK would always fire null since sign-in happens through iOS, not web)
  const unsubscribe = native
    ? () => {}
    : onAuthStateChanged(auth, (user) => {
        callback(
          user ? { uid: user.uid, displayName: user.displayName } : null
        );
      });

  // Listen for native iOS auth callbacks via JS bridge
  const win = window as unknown as {
    __nativeAuthCallback?: (u: AuthUser | null) => void;
    __nativeAuthData?: AuthUser | null;
  };
  win.__nativeAuthCallback = (userData: AuthUser | null) => {
    callback(userData);
  };

  // Check if native already sent auth before we registered the callback
  if (win.__nativeAuthData) {
    callback(win.__nativeAuthData);
  }

  return () => {
    unsubscribe();
    delete (window as unknown as { __nativeAuthCallback?: unknown }).__nativeAuthCallback;
  };
}

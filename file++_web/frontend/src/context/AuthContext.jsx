import React, { createContext, useContext, useState } from 'react';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [provider, setProvider] = useState(null); // 'google', 'microsoft' veya null
  const [token, setToken] = useState(null);
  const [user, setUser] = useState(null);

  const loginMicrosoft = async () => {
    // Microsoft OAuth Popup akışı
    const CLIENT_ID = import.meta.env.VITE_MICROSOFT_CLIENT_ID || "BURAYA_MS_CLIENT_ID";
    const redirectUri = window.location.origin;
    const url = `https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=${CLIENT_ID}&response_type=token&redirect_uri=${encodeURIComponent(redirectUri)}&scope=${encodeURIComponent("Files.ReadWrite User.Read")}`;
    
    const popup = window.open(url, "ms_auth", "width=500,height=600");
    const interval = setInterval(() => {
      try {
        if (!popup || popup.closed) clearInterval(interval);
        if (popup?.location?.href?.includes(redirectUri)) {
          const hash = popup.location.hash;
          const params = new URLSearchParams(hash.replace("#", "?"));
          const accessToken = params.get("access_token");
          if (accessToken) {
            clearInterval(interval);
            popup.close();
            setToken(accessToken);
            setProvider('microsoft');
          }
        }
      } catch {}
    }, 500);
  };

  const loginGoogle = () => {
    // Google OAuth Popup akışı
    const CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || "BURAYA_GOOGLE_CLIENT_ID";
    const redirectUri = window.location.origin;
    const scope = "https://www.googleapis.com/auth/drive.file";
    const url = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=token&scope=${encodeURIComponent(scope)}`;
    
    const popup = window.open(url, "google_auth", "width=500,height=600");
    const interval = setInterval(() => {
      try {
        if (!popup || popup.closed) clearInterval(interval);
        if (popup?.location?.href?.includes(redirectUri)) {
          const hash = popup.location.hash;
          const params = new URLSearchParams(hash.replace("#", "?"));
          const accessToken = params.get("access_token");
          if (accessToken) {
            clearInterval(interval);
            popup.close();
            setToken(accessToken);
            setProvider('google');
          }
        }
      } catch {}
    }, 500);
  };

  const logout = () => {
    setProvider(null);
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ provider, token, user, loginMicrosoft, loginGoogle, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
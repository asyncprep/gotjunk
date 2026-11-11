import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import './i18n';
import './styles.css';
import { AuthProvider } from './lib/auth';
import App from './App';
import { installDiagnostics } from './lib/diagnostics';

// Recent script errors go with a bug report (only if someone sends one).
installDiagnostics();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);

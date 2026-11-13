import { useState, type InputHTMLAttributes, type Ref } from 'react';
import { useTranslation } from 'react-i18next';

// A password field with an eye button that shows or hides what was typed.
export default function PasswordInput({ ref, className, ...props }: Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> & { ref?: Ref<HTMLInputElement> }) {
  const { t } = useTranslation();
  const [shown, setShown] = useState(false);
  const label = shown ? t('common.hidePassword') : t('common.showPassword');
  return (
    <span className={`pw-field ${className ?? ''}`}>
      <input ref={ref} type={shown ? 'text' : 'password'} {...props} />
      <button type="button" className="pw-eye" aria-label={label} title={label} aria-pressed={shown}
        onClick={() => setShown(!shown)}>
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2"
          strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" />
          <circle cx="12" cy="12" r="3" />
          {shown && <line x1="3" y1="3" x2="21" y2="21" />}
        </svg>
      </button>
    </span>
  );
}

import { useState } from 'react';
import { useTranslation } from 'react-i18next';

// Official logo if one has been dropped into public/brand/logo.svg, else a typed wordmark.
export default function Brand({ size = 'header' }: { size?: 'header' | 'large' }) {
  const { t } = useTranslation();
  const [hasLogo, setHasLogo] = useState(true);

  return (
    <span className={`brand brand-${size}`}>
      {hasLogo ? (
        <img src="/brand/logo.svg" alt="1-800-GOT-JUNK?" onError={() => setHasLogo(false)} />
      ) : (
        <span className="wordmark">1-800-GOT-JUNK<span className="q">?</span></span>
      )}
      <span className="brand-sub">{t('app.region')} · {t('app.product')}</span>
    </span>
  );
}

import { useTranslation } from 'react-i18next';
import { useAuth } from '../lib/auth';

// User guides as PDFs (built from docs/guides/*.md by tools/guides/build.mjs, served from public/pdf).
const GUIDES = [
  { key: 'dispatcher', file: 'dispatcher.pdf', roles: ['dispatcher', 'admin', 'senior_ops'] },
  { key: 'crew', file: 'crew.pdf', roles: ['dispatcher', 'admin', 'senior_ops'] },
  { key: 'admin', file: 'admin.pdf', roles: ['admin', 'senior_ops'] },
] as const;

export default function Guides() {
  const { t } = useTranslation();
  const { role } = useAuth();
  const shown = GUIDES.filter((g) => role && (g.roles as readonly string[]).includes(role));

  return (
    <>
      <div className="page-head"><h1>{t('guides.title')}</h1></div>
      <div className="card">
        <p className="muted small">{t('guides.intro')}</p>
        <div className="table-wrap">
          <table>
            <tbody>
              {shown.map((g) => (
                <tr key={g.key}>
                  <td><strong>{t(`guides.${g.key}`)}</strong><div className="small muted">{t(`guides.${g.key}For`)}</div></td>
                  <td className="num">
                    <a href={`/pdf/${g.file}`} target="_blank" rel="noreferrer">{t('guides.open')}</a>
                    {' · '}
                    <a href={`/pdf/${g.file}`} download={`GOT-JUNK ${t(`guides.${g.key}`)}.pdf`}>{t('guides.download')}</a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}

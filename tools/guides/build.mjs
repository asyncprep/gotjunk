// Builds the user guides (docs/guides/*.md) into PDFs the admin offers for download
// (apps/admin/public/pdf/*.pdf). Run: node tools/guides/build.mjs
// Needs Chrome or Edge installed; it prints the HTML to PDF headless.
// The guides use a small part of Markdown only: headings, paragraphs, bold, links, lists, tables.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = resolve(import.meta.dirname, '../..');
const src = join(root, 'docs/guides');
const out = join(root, 'apps/admin/public/pdf');

const BROWSERS = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome', '/usr/bin/chromium',
];
const browser = BROWSERS.find(existsSync);
if (!browser) throw new Error('Chrome or Edge not found');

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const inline = (s) => esc(s)
  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
  .replace(/(^|[\s(])(https:\/\/[^\s)<]+?)(?=[.,;]?(?:\s|$|\)))/g, '$1<a href="$2">$2</a>');

function toHtml(md) {
  const lines = md.replace(/\r/g, '').split('\n');
  const html = [];
  for (let i = 0; i < lines.length;) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    const h = line.match(/^(#{1,3}) (.*)/);
    if (h) { html.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); i++; continue; }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
      const cells = (r) => r.slice(1, -1).split('|').map((c) => inline(c.trim()));
      html.push('<table><thead><tr>' + cells(rows[0]).map((c) => `<th>${c}</th>`).join('') + '</tr></thead><tbody>'
        + rows.slice(2).map((r) => '<tr>' + cells(r).map((c) => `<td>${c}</td>`).join('') + '</tr>').join('')
        + '</tbody></table>');
      continue;
    }
    const list = line.match(/^(\d+\.|-) /);
    if (list) {
      const tag = list[1] === '-' ? 'ul' : 'ol';
      const items = [];
      while (i < lines.length && /^(\d+\.|-) /.test(lines[i])) items.push(lines[i++].replace(/^(\d+\.|-) /, ''));
      html.push(`<${tag}>` + items.map((x) => `<li>${inline(x)}</li>`).join('') + `</${tag}>`);
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^(#|\||\d+\. |- )/.test(lines[i])) para.push(lines[i++]);
    html.push(`<p>${inline(para.join(' '))}</p>`);
  }
  return html.join('\n');
}

const CSS = `
  @page { size: letter; margin: 18mm 16mm; }
  body { font-family: 'Segoe UI', Roboto, Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1d2433; }
  h1 { font-size: 20pt; color: #003f87; margin: 0 0 2pt; }
  h1 + p { color: #5b6475; margin-top: 0; border-bottom: 3px solid #77b82a; padding-bottom: 8pt; }
  h2 { font-size: 13.5pt; color: #003f87; margin: 18pt 0 6pt; break-after: avoid; }
  table { border-collapse: collapse; width: 100%; margin: 6pt 0 10pt; font-size: 9.5pt; break-inside: auto; }
  tr { break-inside: avoid; }
  th { background: #003f87; color: #fff; text-align: left; font-weight: 600; }
  th, td { border: 1px solid #c9d1de; padding: 4pt 6pt; vertical-align: top; }
  tbody tr:nth-child(even) td { background: #f3f6fa; }
  li { margin: 2pt 0; }
  a { color: #003f87; }
`;

mkdirSync(out, { recursive: true });
for (const file of readdirSync(src).filter((f) => f.endsWith('.md'))) {
  const md = readFileSync(join(src, file), 'utf8');
  const title = md.match(/^# (.*)/m)?.[1] ?? file;
  const htmlFile = join(tmpdir(), `guide-${file}.html`);
  writeFileSync(htmlFile, `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${esc(title)}</title>`
    + `<style>${CSS}</style></head><body>${toHtml(md)}</body></html>`);
  const pdf = join(out, file.replace(/\.md$/, '.pdf'));
  execFileSync(browser, ['--headless', '--disable-gpu', '--no-pdf-header-footer',
    `--print-to-pdf=${pdf}`, pathToFileURL(htmlFile).href], { stdio: 'ignore' });
  console.log(`${file} → ${pdf}`);
}

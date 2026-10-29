import Foundation

/// The trusted shell is loaded once. Document text is passed as a JavaScript argument,
/// never interpolated into executable source. Raw Markdown HTML is escaped by the renderer.
public enum MarkdownPreviewPage {
    public static let html = #"""
    <!doctype html>
    <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src livepdf-resource:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
    <style>
    :root { color-scheme: light dark; --bg:#fff; --fg:#24292f; --muted:#656d76; --line:#d8dee4; --code:#f5f6f8; --accent:#0969da; }
    @media(prefers-color-scheme:dark) { :root { --bg:#1e1f22; --fg:#e4e5e7; --muted:#a4a9b2; --line:#3b3e46; --code:#282b31; --accent:#78b7ff; } }
    * { box-sizing: border-box; } html { background:var(--bg); color:var(--fg); overflow-wrap:break-word; }
    body { margin:0; font:16px/1.7 -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; }
    article { max-width:880px; margin:0 auto; padding:36px 44px 100px; }
    article.wide { max-width:none; } article:empty::after { content:"Markdown"; color:var(--muted); }
    h1,h2,h3,h4,h5,h6 { line-height:1.3; margin:1.5em 0 .65em; font-weight:650; scroll-margin-top:24px; }
    h1 { font-size:2em; } h2 { font-size:1.5em; } h3 { font-size:1.25em; }
    h1,h2 { border-bottom:1px solid var(--line); padding-bottom:.3em; } article>:first-child { margin-top:0; }
    p,ul,ol,blockquote,pre,table { margin:0 0 1em; } li>p { margin:0; } li+li { margin-top:.25em; }
    ul,ol { padding-left:1.8em; } li>ul,li>ol { margin:.35em 0; }
    a { color:var(--accent); text-decoration:none; } a:hover { text-decoration:underline; }
    blockquote { margin-left:0; padding:0 1em; border-left:4px solid var(--line); color:var(--muted); }
    code { font: .88em/1.6 ui-monospace,SFMono-Regular,Menlo,monospace; background:var(--code); border-radius:4px; padding:.15em .35em; }
    pre { padding:16px 20px; overflow:auto; background:var(--code); border:1px solid var(--line); border-radius:8px; }
    pre code { padding:0; background:none; } img { max-width:100%; height:auto; }
    table { border-collapse:collapse; display:block; overflow:auto; width:max-content; max-width:100%; }
    th,td { border:1px solid var(--line); padding:8px 14px; } th { background:var(--code); font-weight:600; }
    hr { border:0; height:1px; background:var(--line); margin:2em 0; }
    input[type=checkbox] { accent-color:var(--accent); margin-right:.5em; }
    .task-list { list-style:none; } .task-list-item { margin-left:-1.3em; }
    @media(max-width:600px) { article { padding:24px 22px 70px; } }
    </style></head><body><article id="document"></article>
    <script>
    (() => {
      const article = document.getElementById('document');
      let revision = 0, interaction = 0;
      for (const event of ['wheel','touchstart','pointerdown','keydown']) {
        addEventListener(event, () => interaction++, {passive:true});
      }
      const key = node => node.id ? '#' + node.id : node.tagName + ':' + node.textContent;
      window.livePDF = {
        render(html) {
          const children = [...article.children];
          const anchor = children.find(node => node.getBoundingClientRect().bottom > 0);
          const anchorKey = anchor && key(anchor);
          const occurrence = anchor ? children.slice(0,children.indexOf(anchor)).filter(node => key(node) === anchorKey).length : 0;
          const offset = anchor ? anchor.getBoundingClientRect().top : 0;
          const oldX = scrollX, oldY = scrollY, epoch = interaction, current = ++revision;
          article.innerHTML = html;
          for (const img of article.querySelectorAll('img')) {
            try {
              const url = new URL(img.getAttribute('src'), document.baseURI);
              if (url.protocol === 'livepdf-resource:') {
                url.searchParams.set('_livepdf', String(current));
                img.src = url.href;
              }
            } catch (_) {}
          }
          const replacement = anchor && [...article.children].filter(node => key(node) === anchorKey)[occurrence];
          const restore = () => {
            if (current !== revision || epoch !== interaction) return;
            scrollTo(oldX, replacement ? replacement.getBoundingClientRect().top + scrollY - offset : oldY);
          };
          restore();
          requestAnimationFrame(restore);
          for (const img of article.querySelectorAll('img')) {
            if (!img.complete) { img.addEventListener('load',restore,{once:true}); img.addEventListener('error',restore,{once:true}); }
          }
          return true;
        },
        find(query, backwards) {
          // Use the DOM selection so clearing a query also clears its visible
          // highlight. WKWebView.find("") leaves WebKit's find indicator alive.
          if (!query) { getSelection()?.removeAllRanges(); return false; }
          const found = window.find(query, false, backwards, true, false, false, false);
          if (!found) getSelection()?.removeAllRanges();
          return found;
        },
        fitWidth() { article.classList.add('wide'); },
        actualSize() { article.classList.remove('wide'); }
      };
    })();
    </script></body></html>
    """#
}

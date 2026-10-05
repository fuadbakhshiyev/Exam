(async () => {
  const O = location.origin, out = { dersler: {} };
  out.html = await fetch(O + '/Kullanici/pastexams').then(r => r.text());
  const ids = [...new Set([...out.html.matchAll(/dersegir\(\s*['"]?([^'")]+)['"]?\s*\)/g)].map(m => m[1]))];
  for (const id of ids) {
    out.dersler[id] = await fetch(O + '/Kullanici/pastexamslist/?token=' + encodeURIComponent(id)).then(r => r.text()).catch(e => 'ERR ' + e);
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([JSON.stringify(out)], { type: 'application/json' }));
  a.download = 'oys_pastexams.json';
  a.click();
  console.log('Hazır: oys_pastexams.json,', ids.length, 'fənn');
})();

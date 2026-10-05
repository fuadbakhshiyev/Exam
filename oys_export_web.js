(async () => {
  const TOKEN = 'Mzk2NDI=', AD = 'Web Tasarımının Temelleri', CEHD = 50;
  const O = location.origin, Q = O + '/Kullanici/quiz/', S = O + '/Kullanici/sonuc/';
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const form = { 'Content-Type': 'application/x-www-form-urlencoded' };
  const ders = { token: TOKEN, dersID: '', sorular: {}, cehdler: [] };
  const data = window.__oysWeb = { dersler: { [AD]: ders }, log: [] };
  window.oysSaveWeb = () => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([JSON.stringify(data)], { type: 'application/json' }));
    a.download = 'oys_export_web.json';
    a.click();
  };
  for (let i = 1; i <= CEHD; i++) {
    try {
      const qhtml = await fetch(Q + '?token=' + encodeURIComponent(TOKEN)).then(r => r.text());
      const val = n => (qhtml.match(new RegExp('name="' + n + '"[^>]*value="([^"]*)"')) || qhtml.match(new RegExp('value="([^"]*)"[^>]*name="' + n + '"')) || [])[1] || '';
      const dersID = val('grupID'), dnId = val('dnId'), stk = val('stk');
      if (!dnId || !stk) throw new Error('dnId/stk tapılmadı (giriş bitib?)');
      ders.dersID = dersID;
      const sorular = JSON.parse(await fetch(Q + 'sinavBaslat.php?' + new URLSearchParams({ dersID, denemeId: dnId })).then(r => r.text()));
      await fetch(Q + 'post.php', { method: 'POST', headers: { ...form, fonksiyon: 'sinavibitirmeayarlari' }, body: new URLSearchParams({ dnId }) });
      const fd = new URLSearchParams();
      sorular.forEach(s => fd.append(s.SoruID, ''));
      const html = await fetch(S + '?token=' + encodeURIComponent(stk), { method: 'POST', headers: form, body: fd }).then(r => r.text());
      // DOM yox, xam mətn: variantlardakı HTML teqləri səhifəni pozur
      const cards = html.split('class="dl-soru-card"').slice(1);
      let yeni = 0;
      if (cards.length !== sorular.length) data.log.push(`#${i}: ${cards.length} kart / ${sorular.length} sual`);
      sorular.forEach((s, k) => {
        const c = cards[k] || '';
        const ssid = (c.match(/data-ssid="(\d+)"/) || [])[1] || '';
        const a = (c.match(/Doğru Cevap:\s*<b>\s*([A-E])\s*<\/b>/) || [])[1] || '';
        if (!a) { data.log.push(`#${i} sual ${k + 1} (${s.SoruID}): cavab tapılmadı`); return; }
        if (!ders.sorular[s.SoruID]) {
          ders.sorular[s.SoruID] = { ssid, soruID: s.SoruID, q: s.soruMetni, o: { A: s.CA, B: s.CB, C: s.CC, D: s.CD, E: s.CE }, a, n: 0 };
          yeni++;
        } else if (ders.sorular[s.SoruID].a !== a) data.log.push(`${s.SoruID}: cavab fərqi ${ders.sorular[s.SoruID].a}/${a}`);
        ders.sorular[s.SoruID].n++;
      });
      ders.cehdler.push(yeni);
      console.log(`${AD}: cəhd ${i}/${CEHD}, ${yeni} yeni, cəmi ${Object.keys(ders.sorular).length}`);
    } catch (e) {
      data.log.push(`#${i}: ${e}`);
      console.warn(`cəhd ${i} alınmadı`, e);
      await sleep(3000);
    }
    await sleep(500);
  }
  const list = Object.values(ders.sorular).filter(s => s.ssid);
  let idx = 0;
  await Promise.all([0, 1, 2, 3].map(async () => {
    while (idx < list.length) {
      const s = list[idx++];
      try {
        const f = new FormData(); f.append('sistemSoruId', s.ssid); f.append('dersId', ders.dersID);
        s.unite = await fetch(S + 'post.php', { method: 'POST', headers: { fonksiyon: 'soruUnite' }, body: f }).then(r => r.json());
      } catch (e) { s.unite = null; }
      await sleep(150);
    }
  }));
  console.log('BİTDİ', Object.keys(ders.sorular).length, 'sual; xəbərdarlıq:', data.log.length);
  window.oysSaveWeb();
})();

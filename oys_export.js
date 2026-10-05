(async () => {
  const DERSLER = {
    'ODI1MjE=': 'Grafik Üretim Teknikleri',
    'ODI1MjM=': 'Özgün Baskı Teknikleri',
    'ODI1MjI=': 'Reklam Grafiği',
    'Nzc0NTg=': 'Tasarım Okumaları',
    'Mzk2NDI=': 'Web Tasarımının Temelleri'
  };
  const CEHD = 50, O = location.origin, Q = O + '/Kullanici/quiz/', S = O + '/Kullanici/sonuc/';
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const form = { 'Content-Type': 'application/x-www-form-urlencoded' };
  const data = window.__oys = { dersler: {}, bad: [], log: [] };
  window.oysSave = () => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([JSON.stringify(data)], { type: 'application/json' }));
    a.download = 'oys_export.json';
    a.click();
  };

  async function cehd(token, ders) {
    const r1 = await fetch(Q + '?token=' + encodeURIComponent(token));
    const qdoc = new DOMParser().parseFromString(await r1.text(), 'text/html');
    const val = n => (qdoc.querySelector(`input[name="${n}"]`) || {}).value || '';
    const dersID = val('grupID'), dnId = val('dnId'), stk = val('stk');
    if (!dnId || !stk) throw new Error('dnId/stk tapılmadı (giriş bitib?)');
    const raw = await fetch(Q + 'sinavBaslat.php?' + new URLSearchParams({ dersID, denemeId: dnId })).then(r => r.text());
    let sorular = []; try { sorular = JSON.parse(raw); } catch (e) {}
    await fetch(Q + 'post.php', { method: 'POST', headers: { ...form, fonksiyon: 'sinavibitirmeayarlari' }, body: new URLSearchParams({ dnId }) });
    const fd = new URLSearchParams();
    sorular.forEach(s => fd.append(s.SoruID, ''));
    const html = await fetch(S + '?token=' + encodeURIComponent(stk), { method: 'POST', headers: form, body: fd }).then(r => r.text());
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const cards = [...doc.querySelectorAll('.dl-soru-card')];
    let yeni = 0, ok = cards.length > 0;
    cards.forEach((c, i) => {
      const q = (c.querySelector('.dl-soru-metin') || {}).innerHTML || '';
      const ssid = (c.querySelector('[data-ssid]') || { getAttribute: () => '' }).getAttribute('data-ssid') || '';
      const o = {}; let a = '';
      c.querySelectorAll('.dl-secenek').forEach(s => {
        const harf = ((s.querySelector('.dl-secenek-harf') || {}).textContent || '').trim();
        if (!/^[A-E]$/.test(harf)) return;
        const k = s.cloneNode(true); k.querySelector('.dl-secenek-harf').remove();
        o[harf] = k.innerHTML.trim();
        if (s.classList.contains('is-dogru')) a = harf;
      });
      if (!a) { const m = (c.querySelector('.dl-cevap-info') || {}).textContent || ''; a = (m.match(/Doğru Cevap:\s*([A-E])/) || [])[1] || ''; }
      if (!q.trim() || Object.keys(o).length < 2 || !a) { ok = false; return; }
      const key = ssid || q.trim();
      if (!ders.sorular[key]) {
        ders.sorular[key] = { ssid, soruID: (sorular[i] || {}).SoruID || '', q: q.trim(), o, a, n: 0 };
        yeni++;
      }
      ders.sorular[key].n++;
    });
    if (!ok && data.bad.length < 5) data.bad.push({ token, dnId, html: ((doc.querySelector('.dl-soru-wrap') || doc.body || {}).outerHTML || html).slice(0, 200000) });
    return { n: cards.length, yeni, dersID };
  }

  for (const [token, ad] of Object.entries(DERSLER)) {
    const ders = data.dersler[ad] = { token, dersID: '', sorular: {}, cehdler: [] };
    for (let i = 1; i <= CEHD; i++) {
      try {
        const r = await cehd(token, ders);
        ders.dersID = r.dersID;
        ders.cehdler.push(r.yeni);
        console.log(`${ad}: cəhd ${i}/${CEHD}, ${r.n} sual, ${r.yeni} yeni, cəmi ${Object.keys(ders.sorular).length}`);
      } catch (e) {
        data.log.push(`${ad} #${i}: ${e}`);
        console.warn(`${ad}: cəhd ${i} alınmadı`, e);
        await sleep(3000);
      }
      await sleep(500);
    }
    // Ünite məlumatı (hər unikal sual üçün bir dəfə)
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
    console.log(`${ad}: ünitelər yükləndi (${list.length})`);
  }
  console.log('BİTDİ', Object.fromEntries(Object.entries(data.dersler).map(([k, v]) => [k, Object.keys(v.sorular).length])));
  window.oysSave();
})();

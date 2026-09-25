// Random strings through the game's break_eternity fromString (op|string|expected components).
// usage: node str_gen.js N seed > str_cases.txt
const Decimal=require(require('path').join(__dirname,'..','game-js','technical','break_eternity.js'));
const N=+process.argv[2]||3000; let s=+process.argv[3]||1;
const r=()=>{s=(s*16807)%2147483647;return (s-1)/2147483646};
const pick=a=>a[Math.floor(r()*a.length)];
const bits=['0','1','2','9','.','e','E','-','+',' ','ee','e-','1.5','0.02','x','abc','Infinity','NaN',',','1e400','3.3','e^',')','(','15'];
function rnd(){ const u=r();
  if(u<0.25){ // a real Decimal's toString / a number's String()
    const d=[new Decimal(Math.pow(10,(r()-0.3)*40)), new Decimal('1e'+Math.floor(r()*1e6)), new Decimal('e'+(r()*1e15).toExponential(6)), new Decimal('ee'+(r()*1e15).toExponential(6)),new Decimal(-r()*1e20), new Decimal('1e-'+Math.floor(r()*1e5))];
    return String(pick(d)); }
  if(u<0.45) return String(pick([0.02,0.021,1,5,1e21,1e-7,123.456])) + String(pick([new Decimal(1),new Decimal(2.5),0.02,'',new Decimal('1e50')]))+String(pick(['',0.02,'.5']));
  let t=''; const n=1+Math.floor(r()*6); for(let i=0;i<n;i++) t+=pick(bits); return t;
}
const out=[];
for(let i=0;i<N;i++){ const str=rnd(); if(str.includes('|')||str.includes('\n')||/e\^[^a-z]*(inf|1e400|e)/i.test(str)) continue; const d=new Decimal(str); out.push(str+'|'+[d.sign,d.layer,d.mag].join(',')); }
console.log(out.join('\n'));

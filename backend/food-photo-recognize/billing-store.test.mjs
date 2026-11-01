import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { BillingStore, monthlyWindow } from './billing-store.mjs';
const anchor = Date.UTC(2024,0,31,12);
function setup(t) {
 const dir=mkdtempSync(path.join(tmpdir(),'billing-'));let now=anchor;
 const store=new BillingStore(path.join(dir,'db.sqlite'),{now:()=>now});
 const sub={environment:'Sandbox',originalTransactionId:'123',active:true,anchor,accessUntil:Date.UTC(2025,0,31,12)};
 const wallet=store.wallet(sub);
 const purchase=(id='p1',product='com.weekfit.topup.photos20')=>({environment:'Sandbox',transactionId:id,
  productId:product,appAccountToken:wallet.token,type:'Consumable'});
 t.after(()=>{store.close();rmSync(dir,{recursive:true,force:true});});return {store,sub,wallet,purchase,setNow:v=>now=v};
}
test('UTC month anniversaries preserve original day and leap dates',()=>{
 assert.deepEqual(monthlyWindow(anchor,Date.UTC(2024,1,29,12)),{start:Date.UTC(2024,1,29,12),end:Date.UTC(2024,2,31,12)});
 assert.equal(monthlyWindow(anchor,Date.UTC(2024,2,30)).start,Date.UTC(2024,1,29,12));
 assert.equal(monthlyWindow(Date.UTC(2023,0,31),Date.UTC(2023,1,28)).end,Date.UTC(2023,2,31));
});
test('shared subscription lineage, isolated environments and no overspending',t=>{
 const {store,sub,wallet}=setup(t);assert.deepEqual(store.wallet(sub),wallet);
 assert.notEqual(store.wallet({...sub,environment:'Production'}).id,wallet.id);
 for(let i=0;i<30;i++)store.reserve(wallet,sub,'photos',`photo_${String(i).padStart(4,'0')}`,'image');
 assert.throws(()=>store.reserve(wallet,sub,'photos','photo_0031','image'),{code:'quota_exhausted'});
});
test('one transaction credits once and only to its owner; refunds are idempotent',t=>{
 const {store,sub,wallet,purchase}=setup(t);store.grant(wallet,purchase());store.grant(wallet,purchase());
 assert.equal(store.snapshot(wallet,sub).photos.purchased,20);
 assert.throws(()=>store.grant(store.wallet({...sub,originalTransactionId:'456'}),purchase()),{code:'purchase_owner_mismatch'});
 store.refund(purchase());store.refund(purchase());store.grant(wallet,purchase());assert.equal(store.snapshot(wallet,sub).photos.purchased,0);
});
test('failure refunds original period, topups persist at renewal and expiry, replay cannot spend twice',t=>{
 const {store,sub,wallet,purchase,setNow}=setup(t);store.grant(wallet,purchase());
 const op=store.reserve(wallet,sub,'photos','photo_0001','image');assert.equal(op.included,1);assert.equal(op.purchased,0);
 assert.throws(()=>store.reserve(wallet,sub,'photos','photo_0001','different'),{code:'idempotency_key_reuse'});
 setNow(Date.UTC(2024,1,29,12));store.settle(wallet.id,'photo_0001',0);store.settle(wallet.id,'photo_0001',1);
 assert.equal(store.snapshot(wallet,sub).photos.included,30);assert.equal(store.snapshot(wallet,sub).photos.purchased,20);
 assert.throws(()=>store.reserve(wallet,{...sub,active:false},'photos','photo_0002','image'),{code:'subscription_required'});
 assert.equal(store.snapshot(wallet,{...sub,active:false}).photos.purchased,20);
});
test('finite voice reservation excludes concurrent calls and settles exact seconds once',t=>{
 const {store,sub,wallet}=setup(t);assert.equal(store.reserve(wallet,sub,'voice','voice_0001','call',300).included,300);
 assert.throws(()=>store.reserve(wallet,sub,'voice','voice_0002','call',300),{code:'voice_already_active'});
 store.startCall(wallet.id,'voice_0001');store.settle(wallet.id,'voice_0001',13);store.settle(wallet.id,'voice_0001',100);
 assert.equal(store.snapshot(wallet,sub).voice.included,287);
});
test('refund-before-delivery tombstone and spent-credit debt prevent regranting',t=>{
 const {store,sub,wallet,purchase}=setup(t);store.refund(purchase());store.grant(wallet,purchase());assert.equal(store.snapshot(wallet,sub).photos.purchased,0);
 store.grant(wallet,purchase('p2'));for(let i=0;i<40;i++){const key=`photo_${String(i).padStart(4,'0')}`;store.reserve(wallet,sub,'photos',key,'image');store.settle(wallet.id,key,1);}
 store.refund(purchase('p2'));assert.throws(()=>store.reserve(wallet,sub,'photos','photo_0041','image'),{code:'quota_exhausted'});
});
test('restart retains wallet, pending reservations, balances and idempotency',t=>{
 const dir=mkdtempSync(path.join(tmpdir(),'billing-restart-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const file=path.join(dir,'db.sqlite');
 const sub={environment:'Sandbox',originalTransactionId:'x',active:true,anchor,accessUntil:Date.UTC(2025,0,31)};
 let s=new BillingStore(file,{now:()=>anchor});const wallet=s.wallet(sub);s.reserve(wallet,sub,'photos','photo_0001','image');s.close();
 s=new BillingStore(file,{now:()=>anchor});t.after(()=>s.close());assert.deepEqual(s.wallet(sub),wallet);assert.equal(s.pending().length,1);
 s.settle(wallet.id,'photo_0001',0);assert.equal(s.snapshot(wallet,sub).photos.included,30);
});
test('first checkout and a new subscription lineage recover the same purchased wallet through signed appAccountToken',t=>{
 const {store,sub,wallet,purchase}=setup(t);store.grant(wallet,purchase());
 const renewed={...sub,originalTransactionId:'new-lineage',appAccountToken:wallet.token};
 assert.deepEqual(store.wallet(renewed),wallet);assert.equal(store.snapshot(store.wallet(renewed),renewed).photos.purchased,20);
 const checkout=store.checkoutWallet('anonymous-first-device','Sandbox');
 assert.deepEqual(store.checkoutWallet('anonymous-first-device','Sandbox'),checkout);
 assert.deepEqual(store.wallet({...sub,originalTransactionId:'first-purchase',appAccountToken:checkout.token}),checkout);
});

test('spent refund debt is repaid once, not deducted again in every future month',t=>{
 const {store,sub,wallet,purchase,setNow}=setup(t);store.grant(wallet,purchase());
 for(let i=0;i<40;i++){const key=`photo_${String(i).padStart(4,'0')}`;store.reserve(wallet,sub,'photos',key,'image');store.settle(wallet.id,key,1);}
 store.refund(purchase());setNow(Date.UTC(2024,1,29,12));
 assert.equal(store.snapshot(wallet,sub).photos.included,20);
 assert.equal(store.snapshot(wallet,sub).photos.included,20);
 setNow(Date.UTC(2024,2,31,12));assert.equal(store.snapshot(wallet,sub).photos.included,30);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { createAppleBilling } from './billing-apple.mjs';
const productId='com.weekfit.subscription.monthly';
function fixture({status=1,expiresDate=Date.now()+60000,offerType,price=3490,revocationDate,grace=Date.now()+60000}={}) {
 const tx={productId,originalTransactionId:'123',originalPurchaseDate:Date.now()-86400000,
  inAppOwnershipType:'PURCHASED',environment:'Sandbox',expiresDate,offerType,price,revocationDate};
 const verifier={verifyAndDecodeTransaction:async()=>tx,
  verifyAndDecodeRenewalInfo:async()=>({originalTransactionId:'123',gracePeriodExpiresDate:grace})};
 const api={getAllSubscriptionStatuses:async()=>({data:[{lastTransactions:[{originalTransactionId:'123',status,
  signedTransactionInfo:'signed-tx',signedRenewalInfo:'signed-renewal'}]}]})};
 return createAppleBilling({BILLING_APPLE_ENVIRONMENT:'Sandbox',BILLING_EXISTING_PHOTO_CUTOFF:new Date().toISOString()},{verifier,api});
}
test('active introductory, promotional and offer-code subscriptions are eligible',async()=>{
 for(const offerType of [undefined,1,2,3,4]) {
  const sub=await fixture({offerType,price:offerType?0:3490}).subscription('signed');
  assert.equal(sub.active,true);assert.equal(sub.grandfatheredPhotos,!offerType);
 }
});
test('grace uses signed renewal expiry; billing retry and revoked transactions do not grant access',async()=>{
 assert.equal((await fixture({status:4,expiresDate:Date.now()-1000}).subscription('signed')).active,true);
 assert.equal((await fixture({status:4,expiresDate:Date.now()-1000,grace:Date.now()-1}).subscription('signed')).active,false);
 assert.equal((await fixture({status:3}).subscription('signed')).active,false);
 assert.equal((await fixture({revocationDate:Date.now()-1}).subscription('signed')).active,false);
});
test('expired subscription retains recoverable wallet lineage, without granting AI access',async()=>{
 const sub=await fixture({status:2,expiresDate:Date.now()-1}).subscription('signed');
 assert.equal(sub.active,false);assert.equal(sub.originalTransactionId,'123');
});

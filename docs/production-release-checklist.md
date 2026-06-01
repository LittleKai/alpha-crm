# Alpha CRM Production Release Checklist

## Deploy Verification
- [ ] Backend deployed successfully
- [ ] Frontend deployed successfully
- [ ] MongoDB indexes verified and running

## Client Releases
- [ ] Windows installer build/sign/upload
- [ ] Android APK build/sign/upload
- [ ] Release metadata updated

## Functional Tests
- [ ] Test user purchase by credits
- [ ] Test bank transfer order fulfillment
- [ ] Test Windows registration
- [ ] Test Android pairing
- [ ] Test AI quota decrement
- [ ] Test expired subscription read-only behavior

## Rollback Plan
- Revert backend and frontend to previous tags.
- Restore from MongoDB backup if data migration fails.

# 🚀 Deploy Checklist

## Pre-Deploy Verification

### ✅ Code Quality
- [ ] All tests passing locally: `bundle exec rspec`
- [ ] No security vulnerabilities: `bundle audit`
- [ ] Code linted: `rubocop` (if configured)
- [ ] No pending migrations: `rails db:migrate:status`

### ✅ Environment Configuration
- [ ] All required ENV vars documented in README
- [ ] Staging ENV vars configured in Heroku
- [ ] Database URL configured
- [ ] Redis URL configured (if using cache)
- [ ] Calendly API credentials configured

### ✅ Dependencies
- [ ] Gemfile.lock committed
- [ ] No development/test gems in production
- [ ] Node modules compatible: `npm ci`

### ✅ Database
- [ ] Migrations tested locally
- [ ] Seed data compatible
- [ ] Backup strategy confirmed

## Deploy Commands

### Heroku Deploy Process
```bash
# 1. Deploy to staging first
git push heroku-staging main

# 2. Run migrations
heroku run rails db:migrate --app your-staging-app

# 3. Run smoke tests
heroku run rails smoke_tests:all --app your-staging-app

# 4. Test critical flows
heroku run rails smoke_tests:user_flows --app your-staging-app

# 5. Test Calendly integration
heroku run rails smoke_tests:calendly_api --app your-staging-app
```

## Post-Deploy Verification

### ✅ Staging Tests
- [ ] App loads: `heroku open --app your-staging-app`
- [ ] Login works with hola@enronda.com
- [ ] Professionals CRUD works
- [ ] Events view loads (may show errors without tokens)
- [ ] CSV export works
- [ ] No error logs: `heroku logs --tail --app your-staging-app`

### ✅ Production Deploy
```bash
# Only after staging verification
git push heroku main
heroku run rails db:migrate
heroku run rails smoke_tests:all
```

### ✅ Production Monitoring
- [ ] Application loading successfully
- [ ] No error spikes in logs
- [ ] Database connections stable
- [ ] Redis cache working (if configured)
- [ ] External API calls functional

## Rollback Plan

### If Issues Found
```bash
# Quick rollback to previous version
heroku rollback --app your-app-name

# Or rollback to specific release
heroku releases --app your-app-name
heroku rollback v123 --app your-app-name
```

## Common Issues & Solutions

### Database Issues
```bash
# Reset database if needed (⚠️  DATA LOSS)
heroku pg:reset DATABASE_URL --app your-app-name
heroku run rails db:migrate
heroku run rails db:seed
```

### Asset Issues
```bash
# Clear and recompile assets
heroku run rails assets:clobber
heroku run rails assets:precompile
```

### Environment Variables
```bash
# Check current config
heroku config --app your-app-name

# Set missing variables
heroku config:set VAR_NAME=value --app your-app-name
```

## Testing in Staging

### Manual Test Scenarios
1. **Authentication Flow**
   - [ ] Register with hola@enronda.com ✅
   - [ ] Register with invalid email ❌ (should fail)
   - [ ] Login/logout cycle ✅

2. **Professional Management**
   - [ ] Create new professional ✅
   - [ ] Edit professional details ✅
   - [ ] Delete professional ✅
   - [ ] View professional events ✅

3. **Calendly Integration**
   - [ ] OAuth flow (if configured) ✅
   - [ ] Events loading (may show errors without valid tokens) ✅
   - [ ] CSV export ✅

4. **Error Handling**
   - [ ] Invalid professional ID ✅ (should redirect gracefully)
   - [ ] Missing Calendly tokens ✅ (should show error messages)
   - [ ] Network timeouts ✅ (should not crash app)

## Confidence Indicators

### 🟢 High Confidence Deploy
- All tests pass
- Staging verification complete
- No recent breaking changes
- Team available for monitoring

### 🟡 Medium Confidence Deploy
- Tests pass but minor untested changes
- Limited staging verification
- Deploy during low-traffic hours

### 🔴 Low Confidence Deploy
- Failing tests
- Major architectural changes
- No staging verification
- **RECOMMEND POSTPONING**

## Emergency Contacts

- **Technical Lead**: [Your contact]
- **DevOps**: [DevOps contact]
- **Heroku Support**: Available if critical issues

---

**Remember**: It's better to delay a deploy than to break production! 🛡️
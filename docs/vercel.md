# Vercel Deployment

This repo is Vercel-ready for the backend API through `api/index.js` and `vercel.json`.

## Required Vercel Environment Variables

- `NODE_ENV=production`
- `TRUST_PROXY=1`
- `CORS_ORIGINS=https://your-website-domain.com`
- `DATABASE_URL` or the individual `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- `DB_SSL=true` for Supabase
- `JWT_SECRET`
- `STORAGE_DRIVER=s3`
- `S3_REGION`
- `S3_BUCKET`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `S3_ENDPOINT` for Supabase Storage or another S3-compatible provider
- `S3_PUBLIC_BASE_URL` optional; omit it to use short-lived signed download URLs

## Important

Vercel serverless functions do not provide persistent disk storage. Production PDF storage must use Supabase Storage, S3, Cloudflare R2, or another durable object store.

For Supabase Storage S3 compatibility:

```text
STORAGE_DRIVER=s3
S3_ENDPOINT=https://<project-ref>.supabase.co/storage/v1/s3
S3_BUCKET=question-papers
S3_ACCESS_KEY_ID=<Supabase S3 access key>
S3_SECRET_ACCESS_KEY=<Supabase S3 secret key>
```

The API entrypoint is:

```text
https://your-vercel-project.vercel.app/api
```

## GitHub Auto Deploy

Add these GitHub repository secrets:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

Then every push to `main` that changes backend/Vercel files deploys production through `.github/workflows/vercel-deploy.yml`.

Build APKs with:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-vercel-project.vercel.app/api
```

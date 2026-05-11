# Supabase Setup

PolyH.T uses Supabase for the production PostgreSQL database and can also use Supabase Storage for PDF question papers.

## Database

1. Create a Supabase project.
2. Open the SQL editor.
3. Run `backend/database/schema.sql`.
4. Run migrations in `backend/database/migrations/` in filename order.
5. Add the pooled PostgreSQL connection string to Vercel as `DATABASE_URL`.
6. Set `DB_SSL=true`.

## Storage

1. Create a private bucket named `question-papers`.
2. Create Supabase S3 access keys.
3. Add these Vercel variables:

```text
STORAGE_DRIVER=s3
S3_ENDPOINT=https://<project-ref>.supabase.co/storage/v1/s3
S3_BUCKET=question-papers
S3_ACCESS_KEY_ID=<access-key>
S3_SECRET_ACCESS_KEY=<secret-key>
```

Keep `S3_PUBLIC_BASE_URL` empty for signed, short-lived PDF downloads.

## Secret Hygiene

Do not commit `.env`, `.env.production`, database passwords, JWT secrets, or storage keys. Store them in Vercel environment variables and GitHub repository secrets only.

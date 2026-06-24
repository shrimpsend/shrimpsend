-- Add S3 provider preset id for BYO configuration.
ALTER TABLE s3_config ADD COLUMN IF NOT EXISTS provider_id VARCHAR(32) NOT NULL DEFAULT 'custom';

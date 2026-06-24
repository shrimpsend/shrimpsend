-- 数据胶囊等 S3 服务按「客户端应用」绑定 AccessKey，需保存用户所选应用以便匹配 User-Agent
-- Hibernate ddl-auto=update 也会自动加列；生产可手动执行本脚本

ALTER TABLE s3_config
    ADD COLUMN client_app VARCHAR(32) DEFAULT NULL
        COMMENT 'CSTCloud Data Capsule client binding: s3drive|s3browser|rclone|obsidian|cherry_studio'
        AFTER path_style_access_enabled;

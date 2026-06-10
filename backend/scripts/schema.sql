-- ultrasend 数据库结构
-- 与 JPA 实体 (User, Device, S3Config) 一致，适用于 MySQL 8

-- 创建数据库（可选，若已存在则跳过）
CREATE DATABASE IF NOT EXISTS ultrasend
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE ultrasend;

-- 用户表（邮箱注册）
CREATE TABLE IF NOT EXISTS users (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    email         VARCHAR(255) NOT NULL,
    username      VARCHAR(128) DEFAULT NULL COMMENT '可选展示名',
    password_hash VARCHAR(255) NOT NULL,
    data_encryption_key_enc VARCHAR(512) DEFAULT NULL
        COMMENT '用户 DEK，经服务端 KEK 包装，格式 enc:kek:v1:',
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 设备表
CREATE TABLE IF NOT EXISTS devices (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    device_id  VARCHAR(255) NOT NULL COMMENT '客户端生成的唯一设备 ID',
    name       VARCHAR(255) NOT NULL,
    platform   VARCHAR(16)  DEFAULT NULL COMMENT '设备平台类型',
    lan_http_url VARCHAR(512) DEFAULT NULL COMMENT '局域网 HTTP 传输地址',
    last_seen       DATETIME(3)  DEFAULT NULL COMMENT '最后活跃时间，用于在线状态',
    active          TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '0=已踢出/登出，不计入会员设备上限',
    session_version INT          NOT NULL DEFAULT 0 COMMENT '与 JWT claim dsv 对齐，踢出时递增',
    display_code    SMALLINT     DEFAULT NULL COMMENT '同用户下 1–999 展示码，踢出置 NULL',
    user_id    BIGINT       NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_devices_device_id (device_id),
    UNIQUE KEY uk_devices_user_display_code (user_id, display_code),
    KEY idx_devices_user_id (user_id),
    CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 消息表（按用户分页拉取历史）
CREATE TABLE IF NOT EXISTS messages (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id    BIGINT       NOT NULL,
    data       MEDIUMTEXT   NOT NULL COMMENT 'JSON envelope; text payload.text may be enc:v1 AES-GCM',
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_messages_user_created (user_id, created_at),
    CONSTRAINT fk_messages_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 清理废弃的 web_connection 表（已改用内存缓存管理连接状态）
DROP TABLE IF EXISTS web_connection;

-- S3 配置表（每用户一条）
CREATE TABLE IF NOT EXISTS s3_config (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    user_id          BIGINT       NOT NULL,
    endpoint         VARCHAR(512) DEFAULT NULL,
    region           VARCHAR(255) DEFAULT NULL,
    bucket           VARCHAR(255) DEFAULT NULL,
    access_key_id    VARCHAR(255) DEFAULT NULL,
    secret_access_key VARCHAR(1024) DEFAULT NULL,
    prefers_hosted   TINYINT(1)   NOT NULL DEFAULT 0
        COMMENT '1=用户主动切到内置 S3 但保留自建凭证；0=以自建 S3 为活跃模式',
    path_style_access_enabled TINYINT(1) NOT NULL DEFAULT 1
        COMMENT '1=Path-style URL；0=虚拟托管（bucket 作为子域）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_s3_config_user_id (user_id),
    CONSTRAINT fk_s3_config_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 邮箱验证码表
CREATE TABLE IF NOT EXISTS email_verification_codes (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    email      VARCHAR(255) NOT NULL,
    code       VARCHAR(6)   NOT NULL,
    type       VARCHAR(20)  NOT NULL COMMENT 'REGISTER',
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3)  NOT NULL,
    used       TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_vcode_email_type (email, type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 扫码登录会话表
CREATE TABLE IF NOT EXISTS qr_login_sessions (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    session_id VARCHAR(36)  NOT NULL COMMENT '唯一会话标识 (UUID)',
    status     VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/SCANNED/CONFIRMED/CONSUMED/CANCELLED/EXPIRED',
    user_id    BIGINT       DEFAULT NULL COMMENT '扫码用户 ID，扫码后填入',
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_qr_session_id (session_id),
    KEY idx_qr_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 会员权益表（每用户一条）；device_limit = 档位基础数 + addon_packs*5；海外订阅另有 subscription_expires_at
CREATE TABLE IF NOT EXISTS membership_entitlements (
    id                       BIGINT      NOT NULL AUTO_INCREMENT,
    user_id                  BIGINT      NOT NULL,
    tier_code                VARCHAR(16) NOT NULL DEFAULT 'FREE',
    device_limit             INT         NOT NULL DEFAULT 3,
    addon_packs              INT         NOT NULL DEFAULT 0 COMMENT '增购包数，每包+5台',
    is_lifetime              TINYINT(1)  NOT NULL DEFAULT 1,
    subscription_expires_at  DATETIME(3) DEFAULT NULL COMMENT '海外 Stripe/RC 订阅到期',
    subscription_cancel_at_period_end TINYINT(1) DEFAULT NULL COMMENT 'Stripe 周期末取消自动续费',
    stripe_customer_id       VARCHAR(64)   DEFAULT NULL COMMENT 'Stripe Customer id',
    stripe_subscription_id   VARCHAR(64)   DEFAULT NULL COMMENT 'Stripe Subscription id',
    payment_channel          VARCHAR(16) DEFAULT NULL COMMENT 'FREE/APPLE_RC/GOOGLE_RC/STRIPE/ALIPAY_LIFETIME，当前活跃订阅渠道',
    billing_period           VARCHAR(16) DEFAULT NULL COMMENT 'MONTHLY/YEARLY',
    effective_at             DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at               DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_membership_entitlements_user_id (user_id),
    KEY idx_membership_entitlements_payment_channel (payment_channel),
    CONSTRAINT fk_membership_entitlements_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 订阅渠道冲突表（双轨海外订阅时使用）
CREATE TABLE IF NOT EXISTS subscription_conflicts (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    user_id         BIGINT       NOT NULL,
    detected_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    active_channels VARCHAR(128) NOT NULL COMMENT '冲突渠道，逗号分隔 e.g. STRIPE,APPLE_RC',
    incoming_channel VARCHAR(16) NOT NULL COMMENT '本次 webhook 试图写入的渠道',
    existing_channel VARCHAR(16) NOT NULL COMMENT '原有 payment_channel',
    incoming_tier   VARCHAR(16)  DEFAULT NULL,
    existing_tier   VARCHAR(16)  DEFAULT NULL,
    incoming_expires_at DATETIME(3) DEFAULT NULL,
    existing_expires_at DATETIME(3) DEFAULT NULL,
    resolved_at     DATETIME(3)  DEFAULT NULL,
    note            VARCHAR(512) DEFAULT NULL,
    payload_excerpt VARCHAR(1024) DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_subscription_conflicts_user (user_id),
    KEY idx_subscription_conflicts_unresolved (resolved_at),
    CONSTRAINT fk_subscription_conflicts_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 买断会员订单表
CREATE TABLE IF NOT EXISTS membership_orders (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    order_no            VARCHAR(64)  NOT NULL,
    user_id             BIGINT       NOT NULL,
    from_tier           VARCHAR(16)  NOT NULL,
    to_tier             VARCHAR(16)  NOT NULL,
    payable_amount_cent INT          NOT NULL,
    currency            VARCHAR(8)   NOT NULL DEFAULT 'CNY',
    channel             VARCHAR(16)  NOT NULL COMMENT 'ALIPAY/APPLE_RC/STRIPE',
    order_type          VARCHAR(16)  NOT NULL DEFAULT 'TIER' COMMENT 'TIER=档位购买/升级 ADDON=增购5台',
    status              VARCHAR(24)  NOT NULL COMMENT 'CREATED/PENDING_PAYMENT/PAID/GRANTED/FAILED/CANCELLED',
    provider_order_id   VARCHAR(128) DEFAULT NULL,
    provider_trade_id   VARCHAR(128) DEFAULT NULL,
    provider_payload    TEXT         DEFAULT NULL,
    created_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    paid_at             DATETIME(3)  DEFAULT NULL,
    granted_at          DATETIME(3)  DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_membership_orders_order_no (order_no),
    KEY idx_membership_orders_user_id (user_id),
    KEY idx_membership_orders_status (status),
    CONSTRAINT fk_membership_orders_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 第三方回调幂等事件
CREATE TABLE IF NOT EXISTS membership_order_events (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    provider         VARCHAR(24)  NOT NULL COMMENT 'ALIPAY/REVENUECAT',
    event_type       VARCHAR(64)  NOT NULL,
    event_unique_key VARCHAR(128) NOT NULL,
    order_no         VARCHAR(64)  DEFAULT NULL,
    payload          TEXT         DEFAULT NULL,
    created_at       DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_membership_event_unique (provider, event_unique_key),
    KEY idx_membership_event_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ShrimpSend 海外：内置对象存储（R2）每月上传计量（UTC yyyy-MM）
CREATE TABLE IF NOT EXISTS hosted_upload_usage (
    id           BIGINT      NOT NULL AUTO_INCREMENT,
    user_id      BIGINT      NOT NULL,
    usage_month  VARCHAR(7)  NOT NULL COMMENT 'UTC yyyy-MM',
    upload_bytes BIGINT      NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_hosted_upload_user_month (user_id, usage_month),
    KEY idx_hosted_upload_user (user_id),
    CONSTRAINT fk_hosted_upload_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

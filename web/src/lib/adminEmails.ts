/**
 * 与后端 {@code app.admin.emails} 保持一致，仅用于 UI 展示门禁。
 * 须配置 {@code NEXT_PUBLIC_ADMIN_EMAILS}（客户端 bundle 无法读取无 NEXT_PUBLIC_ 前缀的变量）。
 * 真实权限以后端 {@code AdminAuthService} 为准。
 */
function parseAdminEmails(): Set<string> {
  const raw = process.env.NEXT_PUBLIC_ADMIN_EMAILS ?? '';
  return new Set(
    raw
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .filter(Boolean),
  );
}

export const ADMIN_EMAILS = parseAdminEmails();

export function isAdminEmail(email: string | null | undefined): boolean {
  if (!email) return false;
  return ADMIN_EMAILS.has(email.trim().toLowerCase());
}

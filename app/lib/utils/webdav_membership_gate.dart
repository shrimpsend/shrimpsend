import 'package:flutter/material.dart';

import '../api/membership.dart';
import '../l10n/generated/app_localizations.dart';

/// Returns whether the user may add new WebDAV connections.
bool membershipCanAddWebDav(MembershipMe? me) => me?.canAddWebDav ?? false;

/// Ensures the user may add WebDAV. Shows upgrade dialog when not allowed.
/// Returns `true` if the caller should proceed (e.g. open add form).
Future<bool> ensureCanAddWebDav(
  BuildContext context, {
  MembershipMe? membership,
}) async {
  MembershipMe? me = membership;
  if (me == null) {
    try {
      me = await fetchMyMembership();
    } catch (_) {
      me = null;
    }
  }
  if (membershipCanAddWebDav(me)) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final upgrade = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.webdavMemberOnlyTitle),
      content: Text(l10n.webdavMemberOnlyBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.webdavMemberOnlyAction),
        ),
      ],
    ),
  );
  if (upgrade == true && context.mounted) {
    await Navigator.pushNamed(context, '/settings/membership');
  }
  return false;
}

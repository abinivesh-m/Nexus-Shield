import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../family/family_screen.dart';
import '../org/org_screen.dart';
import '../admin/admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign out?', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign out', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<ApiService>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ApiService>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.red.withValues(alpha: 0.15),
                backgroundImage: (user?.photoUrl.isNotEmpty ?? false) ? NetworkImage(user!.photoUrl) : null,
                child: (user?.photoUrl.isEmpty ?? true)
                    ? Text(
                        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 22),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? '', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
                  if (user != null && !user.isEmailVerified) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('Email not verified', style: GoogleFonts.inter(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Protection'),
          _tile(context, Icons.family_restroom_outlined, 'Family Protection', 'Watch over the people who matter',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()))),
          _tile(context, Icons.apartment_outlined, 'Organization', 'Enterprise dashboard & team monitoring',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgScreen()))),
          if (user?.isAdmin ?? false)
            _tile(context, Icons.admin_panel_settings_outlined, 'Admin Panel', 'Manage users, reports & scam database',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                color: AppColors.orange),
          const SizedBox(height: 16),
          _sectionLabel('Preferences'),
          _tile(context, Icons.settings_outlined, 'Settings', 'Language, notifications, security & appearance',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          const SizedBox(height: 16),
          _sectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: Text('Sign out', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w600)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.textPrim),
        title: Text(title, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

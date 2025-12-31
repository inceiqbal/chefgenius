import 'package:flutter/material.dart';
import 'package:chefgenius/app/data/localization/app_strings_en.dart';
import 'package:chefgenius/app/data/localization/app_strings_id.dart';

class AppStrings {
  final BuildContext context;
  final Locale locale;
  final Map<String, String> _strings;

  AppStrings._(this.context, this.locale, this._strings);

  static AppStrings of(BuildContext context) {
    Locale locale = Localizations.localeOf(context);
    Map<String, String> strings;
    if (locale.languageCode == 'id') {
      strings = indonesianTexts;
    } else {
      strings = englishTexts;
    }
    return AppStrings._(context, locale, strings);
  }

  String get(String key, {Map<String, String>? params}) {
    String? value = _strings[key];
    if (value == null) return key;
    if (params != null) {
      params.forEach((k, v) {
        value = value!.replaceAll('@$k', v);
      });
    }
    return value!;
  }

  // Shortcut getter untuk admin dashboard
  String get adminDashboard => get('admin_dashboard', params: null);
  String get adminTabLaporan => get('admin_tab_laporan', params: null);
  String get adminTabBanding => get('admin_tab_banding', params: null);
  String get adminTabSanksi => get('admin_tab_sanksi', params: null);
  String get adminNoSanctionedUsers => get('admin_no_sanctioned_users', params: null);
  String get adminNoReports => get('admin_no_reports', params: null);
  String get adminNoAppeals => get('admin_no_appeals', params: null);
  String get adminFilterAll => get('admin_filter_all', params: null);
  String get adminFilterPost => get('admin_filter_post', params: null);
  String get adminFilterComment => get('admin_filter_comment', params: null);
}

// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class GeneratedLocalization {
  GeneratedLocalization();

  static GeneratedLocalization? _current;

  static GeneratedLocalization get current {
    assert(_current != null,
        'No instance of GeneratedLocalization was loaded. Try to initialize the GeneratedLocalization delegate before accessing GeneratedLocalization.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<GeneratedLocalization> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = GeneratedLocalization();
      GeneratedLocalization._current = instance;

      return instance;
    });
  }

  static GeneratedLocalization of(BuildContext context) {
    final instance = GeneratedLocalization.maybeOf(context);
    assert(instance != null,
        'No instance of GeneratedLocalization present in the widget tree. Did you add GeneratedLocalization.delegate in localizationsDelegates?');
    return instance!;
  }

  static GeneratedLocalization? maybeOf(BuildContext context) {
    return Localizations.of<GeneratedLocalization>(
        context, GeneratedLocalization);
  }

  /// `en_US`
  String get localeName {
    return Intl.message(
      'en_US',
      name: 'localeName',
      desc: '',
      args: [],
    );
  }

  /// `en`
  String get languageCode {
    return Intl.message(
      'en',
      name: 'languageCode',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get language {
    return Intl.message(
      'English',
      name: 'language',
      desc: '',
      args: [],
    );
  }

  /// `Spinify`
  String get title {
    return Intl.message(
      'Spinify',
      name: 'title',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get errSomethingWentWrong {
    return Intl.message(
      'Something went wrong',
      name: 'errSomethingWentWrong',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get errError {
    return Intl.message(
      'Error',
      name: 'errError',
      desc: '',
      args: [],
    );
  }

  /// `Exception`
  String get errException {
    return Intl.message(
      'Exception',
      name: 'errException',
      desc: '',
      args: [],
    );
  }

  /// `An error has occurred`
  String get errAnErrorHasOccurred {
    return Intl.message(
      'An error has occurred',
      name: 'errAnErrorHasOccurred',
      desc: '',
      args: [],
    );
  }

  /// `An exception has occurred`
  String get errAnExceptionHasOccurred {
    return Intl.message(
      'An exception has occurred',
      name: 'errAnExceptionHasOccurred',
      desc: '',
      args: [],
    );
  }

  /// `Please try again later.`
  String get errTryAgainLater {
    return Intl.message(
      'Please try again later.',
      name: 'errTryAgainLater',
      desc: '',
      args: [],
    );
  }

  /// `Invalid format`
  String get errInvalidFormat {
    return Intl.message(
      'Invalid format',
      name: 'errInvalidFormat',
      desc: '',
      args: [],
    );
  }

  /// `Time out exceeded`
  String get errTimeOutExceeded {
    return Intl.message(
      'Time out exceeded',
      name: 'errTimeOutExceeded',
      desc: '',
      args: [],
    );
  }

  /// `Invalid credentials`
  String get errInvalidCredentials {
    return Intl.message(
      'Invalid credentials',
      name: 'errInvalidCredentials',
      desc: '',
      args: [],
    );
  }

  /// `Unimplemented`
  String get errUnimplemented {
    return Intl.message(
      'Unimplemented',
      name: 'errUnimplemented',
      desc: '',
      args: [],
    );
  }

  /// `Not implemented yet`
  String get errNotImplementedYet {
    return Intl.message(
      'Not implemented yet',
      name: 'errNotImplementedYet',
      desc: '',
      args: [],
    );
  }

  /// `Unsupported operation`
  String get errUnsupportedOperation {
    return Intl.message(
      'Unsupported operation',
      name: 'errUnsupportedOperation',
      desc: '',
      args: [],
    );
  }

  /// `File system error`
  String get errFileSystemException {
    return Intl.message(
      'File system error',
      name: 'errFileSystemException',
      desc: '',
      args: [],
    );
  }

  /// `Assertion error`
  String get errAssertionError {
    return Intl.message(
      'Assertion error',
      name: 'errAssertionError',
      desc: '',
      args: [],
    );
  }

  /// `Bad state error`
  String get errBadStateError {
    return Intl.message(
      'Bad state error',
      name: 'errBadStateError',
      desc: '',
      args: [],
    );
  }

  /// `Bad request`
  String get errBadRequest {
    return Intl.message(
      'Bad request',
      name: 'errBadRequest',
      desc: '',
      args: [],
    );
  }

  /// `Unauthorized`
  String get errUnauthorized {
    return Intl.message(
      'Unauthorized',
      name: 'errUnauthorized',
      desc: '',
      args: [],
    );
  }

  /// `Forbidden`
  String get errForbidden {
    return Intl.message(
      'Forbidden',
      name: 'errForbidden',
      desc: '',
      args: [],
    );
  }

  /// `Not found`
  String get errNotFound {
    return Intl.message(
      'Not found',
      name: 'errNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Not acceptable`
  String get errNotAcceptable {
    return Intl.message(
      'Not acceptable',
      name: 'errNotAcceptable',
      desc: '',
      args: [],
    );
  }

  /// `Request timeout`
  String get errRequestTimeout {
    return Intl.message(
      'Request timeout',
      name: 'errRequestTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Too many requests`
  String get errTooManyRequests {
    return Intl.message(
      'Too many requests',
      name: 'errTooManyRequests',
      desc: '',
      args: [],
    );
  }

  /// `Internal server error`
  String get errInternalServerError {
    return Intl.message(
      'Internal server error',
      name: 'errInternalServerError',
      desc: '',
      args: [],
    );
  }

  /// `Bad gateway`
  String get errBadGateway {
    return Intl.message(
      'Bad gateway',
      name: 'errBadGateway',
      desc: '',
      args: [],
    );
  }

  /// `Service unavailable`
  String get errServiceUnavailable {
    return Intl.message(
      'Service unavailable',
      name: 'errServiceUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Gateway timeout`
  String get errGatewayTimeout {
    return Intl.message(
      'Gateway timeout',
      name: 'errGatewayTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Unknown server error`
  String get errUnknownServerError {
    return Intl.message(
      'Unknown server error',
      name: 'errUnknownServerError',
      desc: '',
      args: [],
    );
  }

  /// `An unknown error was received from the server`
  String get errAnUnknownErrorWasReceivedFromTheServer {
    return Intl.message(
      'An unknown error was received from the server',
      name: 'errAnUnknownErrorWasReceivedFromTheServer',
      desc: '',
      args: [],
    );
  }

  /// `Log Out`
  String get logOutButton {
    return Intl.message(
      'Log Out',
      name: 'logOutButton',
      desc: '',
      args: [],
    );
  }

  /// `Log In`
  String get logInButton {
    return Intl.message(
      'Log In',
      name: 'logInButton',
      desc: '',
      args: [],
    );
  }

  /// `Exit`
  String get exitButton {
    return Intl.message(
      'Exit',
      name: 'exitButton',
      desc: '',
      args: [],
    );
  }

  /// `Sign Up`
  String get signUpButton {
    return Intl.message(
      'Sign Up',
      name: 'signUpButton',
      desc: '',
      args: [],
    );
  }

  /// `Sign In`
  String get signInButton {
    return Intl.message(
      'Sign In',
      name: 'signInButton',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get backButton {
    return Intl.message(
      'Back',
      name: 'backButton',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancelButton {
    return Intl.message(
      'Cancel',
      name: 'cancelButton',
      desc: '',
      args: [],
    );
  }

  /// `Confirm`
  String get confirmButton {
    return Intl.message(
      'Confirm',
      name: 'confirmButton',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get continueButton {
    return Intl.message(
      'Continue',
      name: 'continueButton',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get saveButton {
    return Intl.message(
      'Save',
      name: 'saveButton',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get createButton {
    return Intl.message(
      'Create',
      name: 'createButton',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get deleteButton {
    return Intl.message(
      'Delete',
      name: 'deleteButton',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get editButton {
    return Intl.message(
      'Edit',
      name: 'editButton',
      desc: '',
      args: [],
    );
  }

  /// `Add`
  String get addButton {
    return Intl.message(
      'Add',
      name: 'addButton',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get copyButton {
    return Intl.message(
      'Copy',
      name: 'copyButton',
      desc: '',
      args: [],
    );
  }

  /// `Move`
  String get moveButton {
    return Intl.message(
      'Move',
      name: 'moveButton',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get renameButton {
    return Intl.message(
      'Rename',
      name: 'renameButton',
      desc: '',
      args: [],
    );
  }

  /// `Upload`
  String get uploadButton {
    return Intl.message(
      'Upload',
      name: 'uploadButton',
      desc: '',
      args: [],
    );
  }

  /// `Download`
  String get downloadButton {
    return Intl.message(
      'Download',
      name: 'downloadButton',
      desc: '',
      args: [],
    );
  }

  /// `Share`
  String get shareButton {
    return Intl.message(
      'Share',
      name: 'shareButton',
      desc: '',
      args: [],
    );
  }

  /// `Share link`
  String get shareLinkButton {
    return Intl.message(
      'Share link',
      name: 'shareLinkButton',
      desc: '',
      args: [],
    );
  }

  /// `Remove from starred`
  String get removeFromStarredButton {
    return Intl.message(
      'Remove from starred',
      name: 'removeFromStarredButton',
      desc: '',
      args: [],
    );
  }

  /// `Add to starred`
  String get addToStarredButton {
    return Intl.message(
      'Add to starred',
      name: 'addToStarredButton',
      desc: '',
      args: [],
    );
  }

  /// `Move to trash`
  String get moveToTrashButton {
    return Intl.message(
      'Move to trash',
      name: 'moveToTrashButton',
      desc: '',
      args: [],
    );
  }

  /// `Restore`
  String get restoreButton {
    return Intl.message(
      'Restore',
      name: 'restoreButton',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get emailLabel {
    return Intl.message(
      'Email',
      name: 'emailLabel',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get nameLabel {
    return Intl.message(
      'Name',
      name: 'nameLabel',
      desc: '',
      args: [],
    );
  }

  /// `Surname`
  String get surnameLabel {
    return Intl.message(
      'Surname',
      name: 'surnameLabel',
      desc: '',
      args: [],
    );
  }

  /// `Language selection`
  String get languageSelectionLabel {
    return Intl.message(
      'Language selection',
      name: 'languageSelectionLabel',
      desc: '',
      args: [],
    );
  }

  /// `Upgrade`
  String get upgradeLabel {
    return Intl.message(
      'Upgrade',
      name: 'upgradeLabel',
      desc: '',
      args: [],
    );
  }

  /// `App`
  String get appLabel {
    return Intl.message(
      'App',
      name: 'appLabel',
      desc: '',
      args: [],
    );
  }

  /// `Application`
  String get applicationLabel {
    return Intl.message(
      'Application',
      name: 'applicationLabel',
      desc: '',
      args: [],
    );
  }

  /// `Authenticate`
  String get authenticateLabel {
    return Intl.message(
      'Authenticate',
      name: 'authenticateLabel',
      desc: '',
      args: [],
    );
  }

  /// `Authenticated`
  String get authenticatedLabel {
    return Intl.message(
      'Authenticated',
      name: 'authenticatedLabel',
      desc: '',
      args: [],
    );
  }

  /// `Authentication`
  String get authenticationLabel {
    return Intl.message(
      'Authentication',
      name: 'authenticationLabel',
      desc: '',
      args: [],
    );
  }

  /// `Navigation`
  String get navigationLabel {
    return Intl.message(
      'Navigation',
      name: 'navigationLabel',
      desc: '',
      args: [],
    );
  }

  /// `Database`
  String get databaseLabel {
    return Intl.message(
      'Database',
      name: 'databaseLabel',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get copiedLabel {
    return Intl.message(
      'Copied',
      name: 'copiedLabel',
      desc: '',
      args: [],
    );
  }

  /// `Useful links`
  String get usefulLinksLabel {
    return Intl.message(
      'Useful links',
      name: 'usefulLinksLabel',
      desc: '',
      args: [],
    );
  }

  /// `Current version`
  String get currentVersionLabel {
    return Intl.message(
      'Current version',
      name: 'currentVersionLabel',
      desc: '',
      args: [],
    );
  }

  /// `Latest version`
  String get latestVersionLabel {
    return Intl.message(
      'Latest version',
      name: 'latestVersionLabel',
      desc: '',
      args: [],
    );
  }

  /// `Version`
  String get versionLabel {
    return Intl.message(
      'Version',
      name: 'versionLabel',
      desc: '',
      args: [],
    );
  }

  /// `Size`
  String get sizeLabel {
    return Intl.message(
      'Size',
      name: 'sizeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Type`
  String get typeLabel {
    return Intl.message(
      'Type',
      name: 'typeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Date`
  String get dateLabel {
    return Intl.message(
      'Date',
      name: 'dateLabel',
      desc: '',
      args: [],
    );
  }

  /// `Time`
  String get timeLabel {
    return Intl.message(
      'Time',
      name: 'timeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get statusLabel {
    return Intl.message(
      'Status',
      name: 'statusLabel',
      desc: '',
      args: [],
    );
  }

  /// `Current`
  String get currentLabel {
    return Intl.message(
      'Current',
      name: 'currentLabel',
      desc: '',
      args: [],
    );
  }

  /// `Current user`
  String get currentUserLabel {
    return Intl.message(
      'Current user',
      name: 'currentUserLabel',
      desc: '',
      args: [],
    );
  }

  /// `Application version`
  String get applicationVersionLabel {
    return Intl.message(
      'Application version',
      name: 'applicationVersionLabel',
      desc: '',
      args: [],
    );
  }

  /// `Application information`
  String get applicationInformationLabel {
    return Intl.message(
      'Application information',
      name: 'applicationInformationLabel',
      desc: '',
      args: [],
    );
  }

  /// `Connected devices`
  String get conectedDevicesLabel {
    return Intl.message(
      'Connected devices',
      name: 'conectedDevicesLabel',
      desc: '',
      args: [],
    );
  }

  /// `Renewal date`
  String get renewalDateLabel {
    return Intl.message(
      'Renewal date',
      name: 'renewalDateLabel',
      desc: '',
      args: [],
    );
  }

  /// `API domain`
  String get apiDomain {
    return Intl.message(
      'API domain',
      name: 'apiDomain',
      desc: '',
      args: [],
    );
  }

  /// `Storage`
  String get storageLabel {
    return Intl.message(
      'Storage',
      name: 'storageLabel',
      desc: '',
      args: [],
    );
  }

  /// `Help`
  String get helpLabel {
    return Intl.message(
      'Help',
      name: 'helpLabel',
      desc: '',
      args: [],
    );
  }

  /// `Selected`
  String get selectedLabel {
    return Intl.message(
      'Selected',
      name: 'selectedLabel',
      desc: '',
      args: [],
    );
  }

  /// `You will be logged out from your account`
  String get logOutDescription {
    return Intl.message(
      'You will be logged out from your account',
      name: 'logOutDescription',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate
    extends LocalizationsDelegate<GeneratedLocalization> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<GeneratedLocalization> load(Locale locale) =>
      GeneratedLocalization.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}

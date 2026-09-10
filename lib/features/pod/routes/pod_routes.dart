// ============================================================
// POD / SECONDARY SALES — ROUTE DEFINITIONS
// ------------------------------------------------------------
// Adapted from the standalone POD app's routes.dart.
// Classes renamed to PodRoutes / PodRouteGenerator / PodNavigator
// to avoid collision with SFA routes.
// All route strings prefixed with /pod/ to avoid collision.
// Internal POD navigation still uses these routes within the
// POD Navigator scope (via PodEntryScreen's MaterialApp/Navigator).
// ============================================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:zforce/features/pod/screens/login_screen.dart';
import 'package:zforce/features/pod/screens/splash_screen.dart';
import 'package:zforce/features/pod/screens/main_navigation.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart';
import 'package:zforce/features/pod/screens/upload_status_screen.dart';
import 'package:zforce/features/pod/screens/pod_review_screen.dart';
import 'package:zforce/features/pod/screens/batch_detail_screen.dart';
import 'package:zforce/features/pod/screens/batches_list_screen.dart';
import 'package:zforce/features/pod/screens/notifications_screen.dart';
import 'package:zforce/features/pod/screens/modern_document_upload_screen.dart';
import 'package:zforce/features/pod/screens/documents_list_screen.dart';
import 'package:zforce/features/pod/screens/pod_details_screen.dart';
import 'package:zforce/features/pod/screens/e_invoice_data_screen.dart';
import 'package:zforce/features/pod/screens/profile_screen.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart' as pod_upload;
import 'package:zforce/features/pod/screens/sales_dashboard_screen.dart';
import 'package:zforce/features/pod/widgets/notification_handler.dart';
import 'package:zforce/features/pod/widgets/pdf_preview_bytes_screen.dart';

/// POD Route name constants — all prefixed with /pod/ to avoid SFA collisions.
class PodRoutes {
  static const String splash             = '/pod/';
  static const String login              = '/pod/login';
  static const String mainNavigation     = '/pod/main';
  static const String podUpload          = '/pod/pod-upload';
  static const String uploadStatus       = '/pod/upload-status';
  static const String podReview          = '/pod/pod-review';
  static const String batchDetail        = '/pod/batch-detail';
  static const String batchesList        = '/pod/batches-list';
  static const String notifications      = '/pod/notifications';
  static const String documentUpload     = '/pod/document-upload';
  static const String documentsList      = '/pod/documents-list';
  static const String podDetails         = '/pod/pod-details';
  static const String eInvoiceData       = '/pod/e-invoice-data';
  static const String profile            = '/pod/profile';
  static const String pdfPreview         = '/pod/pdf-preview';
  static const String notificationSettings = '/pod/notification-settings';
  static const String salesAnalytics     = '/pod/sales-analytics';
}

/// POD Route generator — used inside the POD feature Navigator.
class PodRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case PodRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case PodRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case PodRoutes.mainNavigation:
        return MaterialPageRoute(builder: (_) => const MainNavigation());

      case PodRoutes.podUpload:
        return MaterialPageRoute(builder: (_) => const PODUploadScreen());

      case PodRoutes.salesAnalytics:
        return MaterialPageRoute(builder: (_) => const SalesDashboardScreen());

      case PodRoutes.uploadStatus:
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => UploadStatusScreen(
              uploadData: args['uploadData'] as Map<String, dynamic>,
              totalFiles: args['totalFiles'] as int,
            ),
          );
        }
        return _errorRoute('UploadStatusScreen requires uploadData and totalFiles');

      case PodRoutes.podReview:
        if (args is Map<String, dynamic> && args['review'] is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => PodReviewScreen(
              review: args['review'] as Map<String, dynamic>,
            ),
          );
        }
        return _errorRoute('PodReviewScreen requires review payload');

      case PodRoutes.batchDetail:
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => BatchDetailScreen(
              batchId: args['batchId'] as int,
              batch: args['batch'] as dynamic,
            ),
          );
        }
        return _errorRoute('BatchDetailScreen requires batchId');

      case PodRoutes.batchesList:
        return MaterialPageRoute(builder: (_) => const BatchesListScreen());

      case PodRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case PodRoutes.documentUpload:
        return MaterialPageRoute(builder: (_) => const ModernDocumentUploadScreen());

      case PodRoutes.documentsList:
        return MaterialPageRoute(builder: (_) => const DocumentsListScreen());

      case PodRoutes.podDetails:
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => PodDetailsScreen(
              podId: args['podId'] as int,
              documentType: args['documentType'] as String? ?? 'POD',
            ),
          );
        }
        return _errorRoute('PodDetailsScreen requires podId');

      case PodRoutes.eInvoiceData:
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => EInvoiceDataScreen(
              qrData: args['qrData'] as Map<String, dynamic>?,
              fileName: args['fileName'] as String? ?? 'E-Invoice.pdf',
              uploadTime: args['uploadTime'] as DateTime? ?? DateTime.now(),
              podId: args['podId'] as String?,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => EInvoiceDataScreen(
            qrData: null,
            fileName: 'E-Invoice.pdf',
            uploadTime: DateTime.now(),
            podId: null,
          ),
        );

      case PodRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case PodRoutes.pdfPreview:
        if (args is Map<String, dynamic>) {
          if (args.containsKey('pdfBytes')) {
            return MaterialPageRoute(
              builder: (_) => PdfPreviewBytesScreen(
                pdfBytes: args['pdfBytes'] as Uint8List,
                title: args['title'] as String? ?? 'Preview',
              ),
            );
          }
        }
        return _errorRoute('PdfPreview requires pdfFile or pdfBytes');

      case PodRoutes.notificationSettings:
        return MaterialPageRoute(builder: (_) => const NotificationSettings());

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}

/// POD Navigation helper — renamed from AppNavigator to avoid collision.
class PodNavigator {
  static Future<T?> pushNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    T? result,
  }) {
    return Navigator.pushReplacementNamed<T, T>(
      context,
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  static Future<T?> pushNamedAndRemoveUntil<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }
}

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:merolagani/helper/common.dart';
import 'package:merolagani/helper/constant/color.dart';
import 'package:merolagani/helper/constant/router.dart';
import 'package:merolagani/helper/extension_utils/hex_color.dart';
import 'package:merolagani/helper/service_locator.dart';
import 'package:merolagani/presentation/app_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:merolagani/presentation/base/base_bloc.dart';
import 'package:merolagani/presentation/page/notification/my_notification.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:path_provider_ios/path_provider_ios.dart';

import 'package:uni_links/uni_links.dart';

import 'dao/app_database.dart';
import 'presentation/page/payment/payment_process/payment_process_page.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'id', 'title',
    description: "Description", importance: Importance.high, playSound: true);
bool isInit = true;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
String initialRoute = ROUTE_PAGE;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('A bg message just showed up: ${message.messageId}');
  if (Platform.isAndroid) PathProviderAndroid.registerWith();
  if (Platform.isIOS) PathProviderIOS.registerWith();
  await Firebase.initializeApp();
  await setupLocator();
  MyNotification().displayNotification(message);

  debugPrint('A bg message just showed up: ${message.messageId}');
  // ToastHelper.showShort('A bg message just showed up: ${message.from}');
}

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

Future<void> main() async {
  await setupLocator();
  await initFirebase();
  // runApp(TestPage());
  runApp(MyApp(
    appRouter: AppRouter(),
  ));
}

Future<void> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // FirebaseMessaging.instance.setAutoInitEnabled(true);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(channel);
  } else if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    // await FirebaseMessaging.instance
    //     .setForegroundNotificationPresentationOptions(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
  }

  FirebaseMessaging.instance.subscribeToTopic('news');
  FirebaseMessaging.instance.subscribeToTopic('custom');
  FirebaseMessaging.instance.subscribeToTopic('all');
  FirebaseMessaging.instance.subscribeToTopic('Ads');
  if (kDebugMode) {
    FirebaseMessaging.instance.subscribeToTopic('test');
    FirebaseMessaging.instance.subscribeToTopic('langType-news');
  }
  FirebaseMessaging.instance.getToken().then((value) {
    print("token $value");
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint("this is firebase onMessage");
    MyNotification().displayNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint("this is firebase onMessageOpenedApp");

    MyNotification().displayNotification(message);
  });
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    // initialRoute = NOTIFICATION_PAGE;
    displayFirstPage(
        notificationAppLaunchDetails!.notificationResponse!.payload!);
  }
  initUniLinks();

  // MyNotification().firebaseNotification();0

  // if (kReleaseMode) {
  //   FirebaseMessaging.instance.subscribeToTopic('news');
  //   FirebaseMessaging.instance.subscribeToTopic('custom');
  //   FirebaseMessaging.instance.subscribeToTopic('all');
  //   FirebaseMessaging.instance.subscribeToTopic('Ads');
  //
  // } else {
  //   FirebaseMessaging.instance.subscribeToTopic('autodial');
  //   FirebaseMessaging.instance.subscribeToTopic('test');
  //
  // }
}

Future<void> initUniLinks() async {
  // Platform messages may fail, so we use a try/catch PlatformException.
  try {
    final initialLink = await getInitialLink();
    // Parse the link and warn the user, if it is not correct,
    // but keep in mind it could be `null`.
    debugPrint("this is initial Link ${initialLink.toString()}");
  } on PlatformException {
    // Handle exception by warning the user their action did not succeed
    // return?
    debugPrint("Platform Exception");
  }
  linkStream.listen((String? link) {
    // Parse the link and warn the user, if it is not correct
    debugPrint("My Url ${link.toString()}");
    //merolagani://merolagani.com/
    if (link != null) {
      try {
        var parts = link.split('webengage/');
        //my test url merolagani://merolagani.com/test/adbl
        //my live url merolagani://merolagani.com/webengage/megaoffer
        //my live url merolagani://merolagani.com/webengage/services/NewsLetter
        //my live url merolagani://merolagani.com/webengage/services/Data Analytics/5/16
        // Navigator.pushNamed(navigatorKey.currentContext, COMPANY_DETAILS_PAGE,
        //     arguments: parts[1]);
//pageName: services|NewsLetters
        if (parts[1] == "megaoffer") {
          Navigator.of(navigatorKey.currentContext!).pushNamed(MEGA_OFFER_PAGE);
        } else if (parts[1] == "servicesandtraining") {
          Navigator.pushNamed(
              navigatorKey.currentContext!, SERVICE_TRAINING_PAGE);
        } else if (parts[1].contains("services")) {
          var myParts = parts[1].split("/");
          if (myParts.length >= 3) {
            //call payment process page
            Navigator.push(
                navigatorKey.currentState!.overlay!.context,
                MaterialPageRoute<void>(
                  builder: (context) => PaymentProcessPage(
                    title: myParts[1],
                    sId: myParts[2],
                    pkg: myParts[3],
                  ),
                ));
          } else {
            locator<AppDatabase>().service.then((value) {
              for (var item in value) {
                if (item.packageName == myParts[1]) {
                  Common.callPayment(
                      navigatorKey.currentContext!, item.packageName);

                  break;
                }
              }
            });
          }
        } else {
          Navigator.pushReplacementNamed(
              navigatorKey.currentContext!, DASHBOARD_PAGE,
              arguments: false);
        }
      } catch (ex) {}
    }
  }, onError: (err) {
    // Handle exception by warning the user their action did not succeed
    debugPrint("Error: ${err.toString()}");
  });
}

FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
RouteSettings? settings;

class MyApp extends StatelessWidget {
  final AppRouter? appRouter;

  MyApp({@required this.appRouter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch:
            Common.createMaterialColor(HexColor.fromHex(primaryColor)),
      ),
      onGenerateRoute: appRouter?.onGenerateRoute,
      initialRoute: initialRoute,
      builder: EasyLoading.init(),
      navigatorKey: navigatorKey,
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: _analytics)],
      onGenerateInitialRoutes: (String initialRouteName) {
        if (settings == null) {
          settings = RouteSettings(name: initialRoute);
        }
        return [appRouter!.onGenerateRoute(settings!)];
      },
    );
  }
}

void displayFirstPage(String payload) {
  var parts = payload.split(SPLITTER);
  if (parts[0] == "webengage") {
    if (parts[1] == "megaoffer") {
      initialRoute = MEGA_OFFER_PAGE;
    } else if (parts[1] == "ads") {
      Common.openBrowser(parts[2]);
    } else if (parts[1] == "services") {
      if (parts.length >= 4) {
        // pageName :services|Data Analytics|5|13
        //call Payment process page

        initialRoute = PAYMENT_PROCESS_NOTIFICATION_PAGE;
        settings = RouteSettings(name: initialRoute, arguments: payload);
      } else {
        locator<AppDatabase>().service.then((value) {
          for (var item in value) {
            if (item.packageName == parts[2]) {
              initialRoute = PACKAGE_PAGE;

              settings = RouteSettings(name: initialRoute, arguments: item);

              // Navigator.of(navigatorKey.currentState!.overlay!.context)
              //     .pushNamed(PACKAGE_PAGE, arguments: item);
              break;
            }
          }
        });
        // Common.callPayment(navigatorKey.currentState!.overlay!.context, parts[2]);
        //pageName: services|5
      }
    } else {
      initialRoute = ROUTE_PAGE;
    }

    return;
  }
  int? newsId = int.tryParse(parts[1]);
  String? adsLink = parts[2];
  String newsIdAndlanguageType = "$newsId$SPLITTER${parts[3]}";

  bool isAdsLink = false;
  switch (parts[0]) {
    case '/topics/news':
      {
        //call news details page
        initialRoute = NOTIFICATION_NEWS_DETAILS_PAGE;
        settings =
            RouteSettings(name: initialRoute, arguments: newsIdAndlanguageType);
      }
      break;
    case '/topics/test':
    case '/topics/langType-news':
      {
//call news details page
        initialRoute = NOTIFICATION_NEWS_DETAILS_PAGE;
        settings =
            RouteSettings(name: initialRoute, arguments: newsIdAndlanguageType);
      }
      break;
    case '/topics/portfolio':
      {
        if (adsLink == null && adsLink.isEmpty) {
          //call portfolio page
          // DashboardModel model =
          // DashboardModel(5, SimpleLineIcons.briefcase, PORTFOLIO);
          initialRoute = NOTIFICATION_PORTFOLIO_PAGE;
        } else {
          isAdsLink = true;
        }
      }
      break;
    case '/topics/da':
      {
        if (adsLink == null && adsLink.isEmpty) {
          //call Da page

          initialRoute = NOTIFICATION_DA_PAGE;
        } else {
          isAdsLink = true;
        }
      }
      break;
    case '/topics/Ads':
      {
        isAdsLink = true;
      }
      break;
    case '/topics/autodial':
      {
        isAdsLink = true;
      }
      break;
    default:
      {
        if (adsLink == null && adsLink.isEmpty) {
          //call dashboard page
          initialRoute = ROUTE_PAGE;
        } else {
          isAdsLink = true;
        }
      }
  }

  if (isAdsLink) {
    //call url

    Common.openBrowser(adsLink);
    //call Hit counter api
    BaseBloc().notificationHitCount(newsId!);
  }
}

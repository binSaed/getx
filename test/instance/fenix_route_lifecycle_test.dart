import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

int liveControllers = 0;
LifecycleController? controllerHeldByPage;

class LifecycleController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    liveControllers++;
  }

  @override
  void onClose() {
    liveControllers--;
    super.onClose();
  }
}

class ControllerPage extends StatelessWidget {
  const ControllerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    controllerHeldByPage = Get.find<LifecycleController>();
    return const Text('page');
  }
}

Future<void> pumpApp(WidgetTester tester, void Function() register) async {
  Get.reset();
  liveControllers = 0;
  controllerHeldByPage = null;
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/first',
      getPages: [
        GetPage(
          name: '/first',
          page: () => const ControllerPage(),
          binding: BindingsBuilder(register),
        ),
        GetPage(
          name: '/second',
          page: () => const ControllerPage(),
          binding: BindingsBuilder(register),
        ),
        GetPage(name: '/empty', page: () => const Text('empty')),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final registrations = <String, void Function()>{
    'fenix lazyPut': () => Get.lazyPut<LifecycleController>(
          () => LifecycleController(),
          fenix: true,
        ),
    'lazyPut': () =>
        Get.lazyPut<LifecycleController>(() => LifecycleController()),
    'put': () => Get.put<LifecycleController>(LifecycleController()),
  };

  registrations.forEach((name, register) {
    testWidgets('$name closes the controller on every offAll cycle',
        (tester) async {
      await pumpApp(tester, register);

      for (var cycle = 0; cycle < 4; cycle++) {
        expect(liveControllers, 1);
        Get.offAllNamed('/empty');
        await tester.pumpAndSettle();
        expect(liveControllers, 0);
        Get.offAllNamed('/first');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('$name survives offAll between routes sharing a binding',
        (tester) async {
      await pumpApp(tester, register);

      Get.offAllNamed('/second');
      await tester.pumpAndSettle();

      expect(controllerHeldByPage!.isClosed, isFalse);
      expect(identical(Get.find<LifecycleController>(), controllerHeldByPage),
          isTrue);
      expect(liveControllers, 1);

      Get.offAllNamed('/empty');
      await tester.pumpAndSettle();

      expect(liveControllers, 0);
    });
  });
}

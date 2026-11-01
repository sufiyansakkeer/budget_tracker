import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monivo/core/di/injection.dart';

import '../../helpers/in_memory_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => getIt.reset());

  // Registrations are lazy, so a wrong dependency would otherwise only fail
  // the first time a screen asked for it.
  test('every registration can be created', () async {
    await initDependencyInjection(database: await createInMemoryDatabase());

    final created = getIt.findAll<Object>(
      instantiateLazySingletons: true,
      callFactories: true,
    );

    expect(created, isNotEmpty);
    for (final object in created) {
      if (object is BlocBase) await object.close();
    }
  });
}

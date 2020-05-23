import 'dart:io';
import 'dart:typed_data';

import 'package:Tether/global/libs/hive/index.dart';
import 'package:Tether/store/alerts/model.dart';
import 'package:Tether/store/auth/reducer.dart';
import 'package:Tether/store/media/reducer.dart';
import 'package:Tether/store/rooms/actions.dart';
import 'package:Tether/store/sync/actions.dart';
import 'package:Tether/store/sync/reducer.dart';
import 'package:Tether/store/sync/state.dart';
import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:redux_persist_flutter/redux_persist_flutter.dart';

// Temporary State Store
import './alerts/model.dart';
import './search/model.dart';

// Persisted State Stores
import './media/state.dart';
import './rooms/state.dart';
import './settings/state.dart';
import './auth/state.dart';

// Reducers for Stores
import './alerts/reducer.dart';
import './rooms/reducer.dart';
import './search/reducer.dart';
import './settings/reducer.dart';

import 'package:redux_persist/redux_persist.dart';

class AppState extends Equatable {
  final bool loading;
  final AuthStore authStore;
  final AlertsStore alertsStore;
  final MatrixStore matrixStore;
  final MediaStore mediaStore;
  final SettingsStore settingsStore;
  final RoomStore roomStore;
  final SyncStore syncStore;

  AppState({
    this.loading = true,
    this.authStore = const AuthStore(),
    this.alertsStore = const AlertsStore(),
    this.matrixStore = const MatrixStore(),
    this.mediaStore = const MediaStore(),
    this.settingsStore = const SettingsStore(),
    this.roomStore = const RoomStore(),
    this.syncStore = const SyncStore(),
  });

  @override
  List<Object> get props => [
        loading,
        alertsStore,
        authStore,
        matrixStore,
        roomStore,
        settingsStore,
      ];
}

AppState appReducer(AppState state, action) {
  return AppState(
    loading: state.loading,
    authStore: authReducer(state.authStore, action),
    alertsStore: alertsReducer(state.alertsStore, action),
    mediaStore: mediaReducer(state.mediaStore, action),
    roomStore: roomReducer(state.roomStore, action),
    syncStore: syncReducer(state.syncStore, action),
    matrixStore: matrixReducer(state.matrixStore, action),
    settingsStore: settingsReducer(state.settingsStore, action),
  );
}

/**
 * Initialize Store
 * - Hot redux state cache for top level data
 * * Consider still using hive here
 * 
 * PLEASE NOTE redux persist manages when the store
 * should persist and if it can, not where it's persisting too
 * this is why the "storage: MemoryStore()" property is set and
 * the Hive Serializer has been impliemented
 */
Future<Store> initStore() async {
  final persistor = Persistor<AppState>(
    storage: MemoryStorage(),
    serializer: HiveSerializer(),
    throttleDuration: Duration(seconds: 5),
    shouldSave: (Store<AppState> store, dynamic action) {
      switch (action.runtimeType) {
        case SetSyncing:
        case SetSynced:
          print('[Redux Persist] cache skip');
          return false;
        default:
          print('[Redux Persist] caching');
          return true;
      }
    },
  );

  // Finally load persisted store
  var initialState;

  try {
    initialState = await persistor.load();
    print('[Redux Persist] persist loaded successfully');
  } catch (error) {
    print('[Redux Persist] error $error');
  }

  final Store<AppState> store = Store<AppState>(
    appReducer,
    initialState: initialState ?? AppState(),
    middleware: [thunkMiddleware, persistor.createMiddleware()],
  );

  return Future.value(store);
}

/**
 * Hive Serializer
 * 
 * Only reliance on redux is when too save state
 */
class HiveSerializer implements StateSerializer<AppState> {
  @override
  Uint8List encode(AppState state) {
    // Fail whole conversion if user fails
    Cache.state.put(
      state.authStore.runtimeType.toString(),
      state.authStore,
    );

    try {
      Cache.state.put(
        state.syncStore.runtimeType.toString(),
        state.syncStore,
      );
    } catch (error) {
      print('[Hive Storage SyncStore] error - $error');
    }

    try {
      Cache.state.put(
        state.roomStore.runtimeType.toString(),
        state.roomStore,
      );
    } catch (error) {
      print('[Hive Storage RoomStore] error - $error');
    }

    try {
      Cache.state.put(
        state.mediaStore.runtimeType.toString(),
        state.mediaStore,
      );
    } catch (error) {
      print('[Hive Storage MediaStore] - $error');
    }

    try {
      Cache.state.put(
        state.settingsStore.runtimeType.toString(),
        state.settingsStore,
      );
    } catch (error) {
      print('[Hive Storage SettingsStore] error - $error');
    }

    // Disregard redux persist storage saving
    return null;
  }

  AppState decode(Uint8List data) {
    AuthStore authStoreConverted = AuthStore();
    SyncStore syncStoreConverted = SyncStore();
    MediaStore mediaStoreConverted = MediaStore();
    RoomStore roomStoreConverted = RoomStore();
    SettingsStore settingsStoreConverted = SettingsStore();

    authStoreConverted = Cache.state.get(
      authStoreConverted.runtimeType.toString(),
      defaultValue: AuthStore(),
    );

    try {
      syncStoreConverted = Cache.state.get(
        syncStoreConverted.runtimeType.toString(),
        defaultValue: SyncStore(),
      );
    } catch (error) {
      print('[AppState.fromJson - roomStoreConverted] error $error');
    }

    try {
      roomStoreConverted = Cache.state.get(
        roomStoreConverted.runtimeType.toString(),
        defaultValue: RoomStore(),
      );
    } catch (error) {
      print('[AppState.fromJson - roomStoreConverted] error $error');
    }

    try {
      mediaStoreConverted = Cache.state.get(
        mediaStoreConverted.runtimeType.toString(),
        defaultValue: MediaStore(),
      );
    } catch (error) {
      print('[AppState.fromJson - MediaStore] error - $error');
    }

    try {
      settingsStoreConverted = Cache.state.get(
        settingsStoreConverted.runtimeType.toString(),
        defaultValue: SettingsStore(),
      );
    } catch (error) {
      print('[AppState.fromJson - SettingsStore] error $error');
    }

    return AppState(
      loading: false,
      authStore: authStoreConverted,
      syncStore: syncStoreConverted,
      roomStore: roomStoreConverted,
      mediaStore: mediaStoreConverted,
      settingsStore: settingsStoreConverted,
    );
  }
}

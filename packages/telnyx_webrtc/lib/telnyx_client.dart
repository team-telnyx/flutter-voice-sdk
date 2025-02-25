import 'package:connectivity_plus/connectivity_plus.dart';
import 'model/network_reason.dart';
import 'model/call_state.dart';

class TelnyxClient {
  void checkReconnection() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> connectivityResult) {
      if (activeCalls().isEmpty || _isAttaching) return;

      if (connectivityResult.contains(ConnectivityResult.none)) {
        _logger.i('No available network types');
        _handleNetworkLost();
        return;
      }

      if (_isAirplaneModeEnabled(connectivityResult)) {
        _logger.i('Airplane mode enabled');
        _handleNetworkLost(reason: NetworkReason.airplaneMode);
        return;
      }

      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        _logger.i('Network available: ${connectivityResult.join(", ")}');
        _handleNetworkReconnection(NetworkReason.networkSwitch);
      }
    });
  }

  bool _isAirplaneModeEnabled(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.none) &&
           !results.contains(ConnectivityResult.mobile) &&
           !results.contains(ConnectivityResult.wifi);
  }

  void _handleNetworkLost({NetworkReason reason = NetworkReason.networkLost}) {
    for (var call in activeCalls()) {
      if (!call.state.isDropped) {
        call.updateState(CallState.dropped.withReason(reason));
      }
    }
  }

  void _handleNetworkReconnection(NetworkReason reason) {
    for (var call in activeCalls()) {
      if (call.state.isDropped) {
        call.updateState(CallState.reconnecting.withReason(reason));
        _reconnectToSocket();
      }
    }
  }
}

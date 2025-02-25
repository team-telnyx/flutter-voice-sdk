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

      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        _logger.i('Network available: ${connectivityResult.join(", ")}');
        _handleNetworkReconnection(NetworkReason.networkSwitch);
      }
    });
  }

  void _handleNetworkLost() {
    for (var call in activeCalls()) {
      call.updateState(CallState.dropped.withReason(NetworkReason.networkLost));
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

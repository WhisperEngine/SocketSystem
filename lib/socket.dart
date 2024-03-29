library socket_server;

import 'dart:io';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:event_system/event_system.dart';

part 'clients.dart';

class SocketEngine extends Object
    with NotifyMixin, ObservableMixin, SubscriptionMixin {
  HttpServer httpServer;
  Map<String, SocketClient> clients;

  SocketEngine();

  addClient(WebSocket socketClient) async {
    SocketClient client = new SocketClient(socketClient);
    client.observable(this);

    this.observers.forEach((observer) {
      client.observable(observer);
    });

    clients[client.identificator] = client;

    client.on('SocketClientMustBeRemoved', (SocketClient socketClient) async {
      await this.removeClient(socketClient);
    });

    dispatchEvent('SocketClientMustBeRegistered', client);
  }

  removeClient(SocketClient socketClient) async {
    clients.remove(socketClient.identificator);
  }

  writeToAllClients(String message,
      {Map details, String exceptClientIdentificator}) async {
    clients.forEach((String identificator, SocketClient client) async {
      if (exceptClientIdentificator != null) {
        if (identificator == exceptClientIdentificator) return;
      }
      client.write(message, details);
    });
  }

  _handleWebSocket(WebSocket socket) async {
    addClient(socket);
  }

  _serveRequest(HttpRequest request) async {
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }

  powerUp({String ip, int port}) async {
    if (clients == null) clients = new Map<String, SocketClient>();
    if (ip == null) ip = InternetAddress.LOOPBACK_IP_V4.host;
    if (port == null) port = 8181;

    httpServer = await HttpServer.bind(ip, port, shared: true);
    print('Socket listen on: http://$ip:$port');

    httpServer.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocket socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(socket);
      } else {
        print("Regular ${request.method} request for: ${request.uri.path}");
        _serveRequest(request);
      }
    });
  }
}

/// SOURCE: https://github.com/amorevino/ory-showcase-apps/blob/main/ory_app/lib/services/auth_service.dart
Map<String, String> checkForErrors(Map<String, dynamic> response) {
  //for errors see https://www.ory.sh/kratos/docs/reference/api#operation/initializeSelfServiceLoginFlowWithoutBrowser
  final ui = Map<String, dynamic>.from(response["ui"]);
  final list = ui["nodes"];
  final generalErrors = ui["messages"];

  Map errors = <String, String>{};
  for (var i = 0; i < list.length; i++) {
    //check if there are any input errors
    final entry = Map<String, dynamic>.from(list[i]);
    if ((entry["messages"] as List).isNotEmpty) {
      final String name = entry["attributes"]["name"];
      final message = entry["messages"][0] as Map<String, dynamic>;
      errors.putIfAbsent(name, () => message["text"] as String);
    }
  }

  if (generalErrors != null) {
    //check if there is a general error
    final message = (generalErrors as List)[0] as Map<String, dynamic>;
    errors.putIfAbsent("general", () => message["text"] as String);
  }

  return errors as Map<String, String>;
}

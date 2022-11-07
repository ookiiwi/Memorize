import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'connection_event.dart';
part 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  ConnectionBloc(super.initialState) {
    on<ConnectionAvailable>(_onConnectionAvailable);
    on<ConnectionUnavailable>(_onConnectionUnavailable);
  }

  Future<void> _onConnectionAvailable(
      ConnectionEvent event, Emitter<ConnectionState> emit) async {
    emit(const ConnectionState(true));

    //  TODO: check offline events
  }

  Future<void> _onConnectionUnavailable(
      ConnectionEvent event, Emitter<ConnectionState> emit) async {
    emit(const ConnectionState(false));
  }
}

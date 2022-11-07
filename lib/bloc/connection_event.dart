part of 'connection_bloc.dart';

abstract class ConnectionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionAvailable extends ConnectionEvent {}

class ConnectionUnavailable extends ConnectionEvent {}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/invite_entity.dart';
import '../../domain/repositories/invite_repository.dart';
import '../../data/repositories/invite_repository_impl.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepositoryImpl();
});

final pendingInvitesProvider = StreamProvider<List<InviteEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return const Stream.empty();
  }
  final repo = ref.watch(inviteRepositoryProvider);
  return repo.watchMyPendingInvites(user.uid);
});

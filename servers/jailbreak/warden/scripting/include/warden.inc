#if defined _warden_included
  #endinput
#endif
#define _warden_included

/* Start Natives */
native bool Warden_IsTaken();
native bool Warden_IsAllowed();
native bool Warden_IsEnabled();
native bool Warden_IsWarden(int client);
native void Warden_Set(int client);
native void Warden_Remove();
/* End Natives */

/* Start Forwards */
forward void OnNewWarden(int client);
forward void OnWardenRemove();
/* End Forwards */

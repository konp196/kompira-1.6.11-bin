��|�         WA ��|�   SE Linux Module                   kompira   1.0.0@                   d   d          U             bluetooth_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       $             netlink_audit_socket      map      nlmsg_relay   
   append      bind      connect      create      write      nlmsg_tty_audit      relabelfrom      ioctl	      name_bind      nlmsg_readpriv      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read
                    tcp_socket      map   
   append      bind      connect      create      write      relabelfrom
      acceptfrom	      connectto      ioctl	      name_bind	      node_bind      newconn      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      name_connect      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen          
   
       msgq	      associate      create      write	      unix_read      destroy      getattr      setattr      read   
   enqueue
   	   unix_write       J             rose_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       2             binder      impersonate      transfer      call      set_context_mgr                    dir      map      rmdir   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access      remove_name      getattr      setattr      add_name      reparent      execmod      read      rename      search      lock	   	   relabelto      mounton      open      quotaon      swapon       .             peer      recv       T             tipc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                    blk_file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access      getattr      setattr      execmod      read      rename      lock	   	   relabelto      mounton      open      quotaon      swapon       
             chr_file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access
      entrypoint      getattr      setattr      execmod      read      rename      lock	   	   relabelto      execute_no_trans      mounton      open      quotaon      swapon          	   	       ipc	      associate      create      write	      unix_read      destroy      getattr      setattr      read
   	   unix_write
       E             ipx_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       	             lnk_file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access      getattr      setattr      execmod      read      rename      lock	   	   relabelto      mounton      open      quotaon      swapon       5             netlink_connector_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                    process      getcap      setcap      sigstop      sigchld	      getrlimit      share      execheap
      setcurrent      setfscreate      setkeycreate      siginh      dyntransition
      transition      fork
      getsession
      noatsecure      sigkill      signull	      setrlimit      getattr   	   getsched      setexec   
   setsched      getpgid      setpgid      ptrace	      execstack	      rlimitinh      setsockcreate      signal      execmem       L             atmsvc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       /             capability2
      epolwakeup      checkpoint_restore      mac_override	      mac_admin
      audit_read      syslog      block_suspend
      wake_alarm                    fd      use
       ]             nfc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       *             packet      forward_out      flow_out      send      recv
      forward_in	      relabelto      flow_in                    socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       G             bridge_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       ?               cap_userns       setfcap   	   setpcap      fowner      sys_boot      sys_tty_config      net_raw	      sys_admin
      sys_chroot
      sys_module	      sys_rawio      dac_override	      ipc_owner      kill      dac_read_search	      sys_pacct      net_broadcast      net_bind_service      sys_nice      sys_time      fsetid      mknod      setgid      setuid      lease	      net_admin      audit_write   
   linux_immutable
      sys_ptrace      audit_control      ipc_lock      sys_resource      chown	                    fifo_file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access      getattr      setattr      execmod      read      rename      lock	   	   relabelto      mounton      open      quotaon      swapon                    file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access
      entrypoint      getattr      setattr      execmod      read      rename      lock	   	   relabelto      execute_no_trans      mounton      open      quotaon      swapon                    node
      rawip_recv      tcp_recv      udp_recv
      rawip_send      tcp_send      udp_send	      dccp_recv	   	   dccp_send      enforce_dest      sendto   
   recvfrom       A             process2      nosuid_transition      nnp_transition       b             bpf	      prog_load	      map_write      map_read
      map_create      prog_run       K             decnet_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       N             irda_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       Y             phonet_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       !             netlink_nflog_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       M             rds_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       B             sctp_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind	      node_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      name_connect      read      setopt      shutdown      recvfrom      association      lock	   	   relabelto      listen
       c             xdp_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       +             key      create      write      view      link      setattr      read      search       6             netlink_netfilter_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen	       Q             ib_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       3             netlink_iscsi_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                     netlink_tcpdiag_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read                    unix_stream_socket      map   
   append      bind      connect      create      write      relabelfrom
      acceptfrom	      connectto      ioctl	      name_bind      newconn      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       0             kernel_service      create_files_as      use_as_override                    netlink_route_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read       O             pppox_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       Z             ieee802154_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       <             infiniband_endport      manage_subnet       9             netlink_rdma_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       F             netrom_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen          
   
       shm	      associate      create      write	      unix_read      destroy      getattr      setattr      read   
   lock
   	   unix_write
       P             llc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       #             netlink_selinux_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
                      capability       setfcap   	   setpcap      fowner      sys_boot      sys_tty_config      net_raw	      sys_admin
      sys_chroot
      sys_module	      sys_rawio      dac_override	      ipc_owner      kill      dac_read_search	      sys_pacct      net_broadcast      net_bind_service      sys_nice      sys_time      fsetid      mknod      setgid      setuid      lease	      net_admin      audit_write   
   linux_immutable
      sys_ptrace      audit_control      ipc_lock      sys_resource      chown       R             mpls_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       %             netlink_ip6fw_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read       @             cap2_userns      checkpoint_restore      mac_override	      mac_admin
      audit_read      syslog      block_suspend
      wake_alarm       ,             dccp_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind	      node_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      name_connect      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       V             iucv_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                    netlink_firewall_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read	                    sock_file      map   
   append      create      execute      write      relabelfrom      link      unlink      ioctl      audit_access      getattr      setattr      execmod      read      rename      lock	   	   relabelto      mounton      open      quotaon      swapon                    unix_dgram_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       _             kcm_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       (             netlink_kobject_uevent_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       ^             vsock_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
          
   
       filesystem	      associate   
   quotaget      relabelfrom
      transition      getattr   	   quotamod      mount      remount      unmount	      relabelto       "             netlink_xfrm_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      nlmsg_write      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
      nlmsg_read       W             rxrpc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       S             can_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       &             netlink_dnrt_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       7             netlink_generic_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       H             atmpvc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       D             ax25_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       8             netlink_scsitransport_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       =             service      stop      status      disable      enable      reload      start
       I             x25_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       X             isdn_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
                    key_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen          
   
       netif
      rawip_recv      tcp_recv      udp_recv
      rawip_send   
   egress   	   ingress      tcp_send      udp_send	      dccp_recv	      dccp_send                    packet_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       d             perf_event
      tracepoint      write      read      cpu      kernel      open
       -             memprotect	      mmap_zero                    msg      send      receive       `             qipcrtr_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
       1             tun_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      attach_queue      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen
                    udp_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind	      node_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       )             appletalk_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       :             netlink_crypto_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       >             proxy      read                    rawip_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind	      node_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       '             association
      setcontext      sendto      recvfrom      polmatch       [             caif_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                    netlink_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       ;             infiniband_pkey      access          	   	       sem	      associate      create      write	      unix_read      destroy      getattr      setattr      read
   	   unix_write                    system      stop   	   status      module_request      reboot      disable      enable      module_load	      undefined      ipc_info      syslog_read      halt      reload   
   start      syslog_console
      syslog_mod
       \             alg_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       C             icmp_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind	      node_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen       4             netlink_fib_lookup_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                    security      compute_member      compute_user      compute_create
      setenforce      check_context      setcheckreqprot      validate_trans      compute_relabel   	   setbool      load_policy      read_policy   
   setsecparam
      compute_av
       a             smc_socket      map   
   append      bind      connect      create      write      relabelfrom      ioctl	      name_bind      sendto      recv_msg      send_msg      getattr      setattr      accept      getopt      read      setopt      shutdown      recvfrom      lock	   	   relabelto      listen                object_r@           @           @                   @                     system_r@   @                 @           @                   @                 	                @   @           �      file_type                @           httpd_sys_content_t                @           kompira_licence_t                @           etc_t                @           sysfs_t                @           tmpfs_t                @   @           �      non_security_file_type                @           memcached_t                @           kompira_config_t                @           kompira_module_t                @           kompira_log_t                  @           kompira_http_content_t                @           httpd_modules_t                @           kompira_repository_t                @           unconfined_service_t                @   @           �      non_auth_file_type                @           cgroup_t                @           httpd_t                @           tmp_t                @           var_t                @   @           �      logfile                @   @           0      security_file_type                @           httpd_log_t
                @           rabbitmq_t                @           kompira_secret_t   
             @           kompira_opt_t   	             @           kompira_var_t	                @           var_run_t
                @   @           @      configfile                             s0   @                           c0          c10   e       c100   �      c1000   �      c1010   �      c1020   o       c110   y       c120   �       c130   �       c140   �       c150   �       c160   �       c170   �       c180   �       c190          c20   �       c200   �       c210   �       c220   �       c230   �       c240   �       c250         c260         c270         c280   #      c290          c30   -      c300   7      c310   A      c320   K      c330   U      c340   _      c350   i      c360   s      c370   }      c380   �      c390   )       c40   �      c400   �      c410   �      c420   �      c430   �      c440   �      c450   �      c460   �      c470   �      c480   �      c490   3       c50   �      c500   �      c510   	      c520         c530         c540   '      c550   1      c560   ;      c570   E      c580   O      c590   =       c60   Y      c600   c      c610   m      c620   w      c630   �      c640   �      c650   �      c660   �      c670   �      c680   �      c690   G       c70   �      c700   �      c710   �      c720   �      c730   �      c740   �      c750   �      c760         c770         c780         c790   Q       c80   !      c800   +      c810   5      c820   ?      c830   I      c840   S      c850   ]      c860   g      c870   q      c880   {      c890   [       c90   �      c900   �      c910   �      c920   �      c930   �      c940   �      c950   �      c960   �      c970   �      c980   �      c990          c1   �      c1001   f       c101   �      c1011   �      c1021          c11   p       c111   z       c121   �       c131   �       c141   �       c151   �       c161   �       c171   �       c181   �       c191   �       c201          c21   �       c211   �       c221   �       c231   �       c241   �       c251         c261         c271         c281   $      c291   .      c301           c31   8      c311   B      c321   L      c331   V      c341   `      c351   j      c361   t      c371   ~      c381   �      c391   �      c401   *       c41   �      c411   �      c421   �      c431   �      c441   �      c451   �      c461   �      c471   �      c481   �      c491   �      c501   4       c51          c511   
      c521         c531         c541   (      c551   2      c561   <      c571   F      c581   P      c591   Z      c601   >       c61   d      c611   n      c621   x      c631   �      c641   �      c651   �      c661   �      c671   �      c681   �      c691   �      c701   H       c71   �      c711   �      c721   �      c731   �      c741   �      c751   �      c761         c771         c781         c791   "      c801   R       c81   ,      c811   6      c821   @      c831   J      c841   T      c851   ^      c861   h      c871   r      c881   |      c891   �      c901   \       c91   �      c911   �      c921   �      c931   �      c941   �      c951   �      c961   �      c971   �      c981   �      c991   �      c1002   �      c1012   g       c102   �      c1022   q       c112          c12   {       c122   �       c132   �       c142   �       c152   �       c162   �       c172   �       c182   �       c192          c2   �       c202   �       c212          c22   �       c222   �       c232   �       c242   �       c252         c262         c272         c282   %      c292   /      c302   9      c312   !       c32   C      c322   M      c332   W      c342   a      c352   k      c362   u      c372         c382   �      c392   �      c402   �      c412   +       c42   �      c422   �      c432   �      c442   �      c452   �      c462   �      c472   �      c482   �      c492   �      c502         c512   5       c52         c522         c532         c542   )      c552   3      c562   =      c572   G      c582   Q      c592   [      c602   e      c612   ?       c62   o      c622   y      c632   �      c642   �      c652   �      c662   �      c672   �      c682   �      c692   �      c702   �      c712   I       c72   �      c722   �      c732   �      c742   �      c752   �      c762         c772         c782         c792   #      c802   -      c812   S       c82   7      c822   A      c832   K      c842   U      c852   _      c862   i      c872   s      c882   }      c892   �      c902   �      c912   ]       c92   �      c922   �      c932   �      c942   �      c952   �      c962   �      c972   �      c982   �      c992   �      c1003   �      c1013          c1023   h       c103   r       c113   |       c123          c13   �       c133   �       c143   �       c153   �       c163   �       c173   �       c183   �       c193   �       c203   �       c213   �       c223          c23   �       c233   �       c243   �       c253         c263         c273         c283   &      c293          c3   0      c303   :      c313   D      c323   "       c33   N      c333   X      c343   b      c353   l      c363   v      c373   �      c383   �      c393   �      c403   �      c413   �      c423   ,       c43   �      c433   �      c443   �      c453   �      c463   �      c473   �      c483   �      c493   �      c503         c513         c523   6       c53         c533          c543   *      c553   4      c563   >      c573   H      c583   R      c593   \      c603   f      c613   p      c623   @       c63   z      c633   �      c643   �      c653   �      c663   �      c673   �      c683   �      c693   �      c703   �      c713   �      c723   J       c73   �      c733   �      c743   �      c753   �      c763         c773         c783         c793   $      c803   .      c813   8      c823   T       c83   B      c833   L      c843   V      c853   `      c863   j      c873   t      c883   ~      c893   �      c903   �      c913   �      c923   ^       c93   �      c933   �      c943   �      c953   �      c963   �      c973   �      c983   �      c993   �      c1004   �      c1014   i       c104   s       c114   }       c124   �       c134          c14   �       c144   �       c154   �       c164   �       c174   �       c184   �       c194   �       c204   �       c214   �       c224   �       c234          c24   �       c244   �       c254   	      c264         c274         c284   '      c294   1      c304   ;      c314   E      c324   O      c334   #       c34   Y      c344   c      c354   m      c364   w      c374   �      c384   �      c394          c4   �      c404   �      c414   �      c424   �      c434   -       c44   �      c444   �      c454   �      c464   �      c474   �      c484   �      c494   �      c504         c514         c524         c534   7       c54   !      c544   +      c554   5      c564   ?      c574   I      c584   S      c594   ]      c604   g      c614   q      c624   {      c634   A       c64   �      c644   �      c654   �      c664   �      c674   �      c684   �      c694   �      c704   �      c714   �      c724   �      c734   K       c74   �      c744   �      c754   �      c764         c774         c784         c794   %      c804   /      c814   9      c824   C      c834   U       c84   M      c844   W      c854   a      c864   k      c874   u      c884         c894   �      c904   �      c914   �      c924   �      c934   _       c94   �      c944   �      c954   �      c964   �      c974   �      c984   �      c994   �      c1005   �      c1015   j       c105   t       c115   ~       c125   �       c135   �       c145          c15   �       c155   �       c165   �       c175   �       c185   �       c195   �       c205   �       c215   �       c225   �       c235   �       c245          c25          c255   
      c265         c275         c285   (      c295   2      c305   <      c315   F      c325   P      c335   Z      c345   $       c35   d      c355   n      c365   x      c375   �      c385   �      c395   �      c405   �      c415   �      c425   �      c435   �      c445   .       c45   �      c455   �      c465   �      c475   �      c485   �      c495          c5   �      c505         c515         c525         c535   "      c545   8       c55   ,      c555   6      c565   @      c575   J      c585   T      c595   ^      c605   h      c615   r      c625   |      c635   �      c645   B       c65   �      c655   �      c665   �      c675   �      c685   �      c695   �      c705   �      c715   �      c725   �      c735   �      c745   L       c75   �      c755   �      c765         c775         c785         c795   &      c805   0      c815   :      c825   D      c835   N      c845   V       c85   X      c855   b      c865   l      c875   v      c885   �      c895   �      c905   �      c915   �      c925   �      c935   �      c945   `       c95   �      c955   �      c965   �      c975   �      c985   �      c995   �      c1006   �      c1016   k       c106   u       c116          c126   �       c136   �       c146   �       c156          c16   �       c166   �       c176   �       c186   �       c196   �       c206   �       c216   �       c226   �       c236   �       c246         c256          c26         c266         c276         c286   )      c296   3      c306   =      c316   G      c326   Q      c336   [      c346   e      c356   %       c36   o      c366   y      c376   �      c386   �      c396   �      c406   �      c416   �      c426   �      c436   �      c446   �      c456   /       c46   �      c466   �      c476   �      c486   �      c496   �      c506         c516         c526         c536   #      c546   -      c556   9       c56   7      c566   A      c576   K      c586   U      c596          c6   _      c606   i      c616   s      c626   }      c636   �      c646   �      c656   C       c66   �      c666   �      c676   �      c686   �      c696   �      c706   �      c716   �      c726   �      c736   �      c746   �      c756   M       c76   �      c766   	      c776         c786         c796   '      c806   1      c816   ;      c826   E      c836   O      c846   Y      c856   W       c86   c      c866   m      c876   w      c886   �      c896   �      c906   �      c916   �      c926   �      c936   �      c946   �      c956   a       c96   �      c966   �      c976   �      c986   �      c996   �      c1007   �      c1017   l       c107   v       c117   �       c127   �       c137   �       c147   �       c157   �       c167          c17   �       c177   �       c187   �       c197   �       c207   �       c217   �       c227   �       c237   �       c247         c257         c267          c27         c277          c287   *      c297   4      c307   >      c317   H      c327   R      c337   \      c347   f      c357   p      c367   &       c37   z      c377   �      c387   �      c397   �      c407   �      c417   �      c427   �      c437   �      c447   �      c457   �      c467   0       c47   �      c477   �      c487   �      c497   �      c507         c517         c527         c537   $      c547   .      c557   8      c567   :       c57   B      c577   L      c587   V      c597   `      c607   j      c617   t      c627   ~      c637   �      c647   �      c657   �      c667   D       c67   �      c677   �      c687   �      c697          c7   �      c707   �      c717   �      c727   �      c737   �      c747   �      c757          c767   N       c77   
      c777         c787         c797   (      c807   2      c817   <      c827   F      c837   P      c847   Z      c857   d      c867   X       c87   n      c877   x      c887   �      c897   �      c907   �      c917   �      c927   �      c937   �      c947   �      c957   �      c967   b       c97   �      c977   �      c987   �      c997   �      c1008   �      c1018   m       c108   w       c118   �       c128   �       c138   �       c148   �       c158   �       c168   �       c178          c18   �       c188   �       c198   �       c208   �       c218   �       c228   �       c238   �       c248         c258         c268         c278          c28   !      c288   +      c298   5      c308   ?      c318   I      c328   S      c338   ]      c348   g      c358   q      c368   {      c378   '       c38   �      c388   �      c398   �      c408   �      c418   �      c428   �      c438   �      c448   �      c458   �      c468   �      c478   1       c48   �      c488   �      c498   �      c508         c518         c528         c538   %      c548   /      c558   9      c568   C      c578   ;       c58   M      c588   W      c598   a      c608   k      c618   u      c628         c638   �      c648   �      c658   �      c668   �      c678   E       c68   �      c688   �      c698   �      c708   �      c718   �      c728   �      c738   �      c748   �      c758         c768         c778   O       c78         c788         c798   	       c8   )      c808   3      c818   =      c828   G      c838   Q      c848   [      c858   e      c868   o      c878   Y       c88   y      c888   �      c898   �      c908   �      c918   �      c928   �      c938   �      c948   �      c958   �      c968   �      c978   c       c98   �      c988   �      c998   �      c1009   �      c1019   n       c109   x       c119   �       c129   �       c139   �       c149   �       c159   �       c169   �       c179   �       c189          c19   �       c199   �       c209   �       c219   �       c229   �       c239   �       c249         c259         c269         c279   "      c289          c29   ,      c299   6      c309   @      c319   J      c329   T      c339   ^      c349   h      c359   r      c369   |      c379   �      c389   (       c39   �      c399   �      c409   �      c419   �      c429   �      c439   �      c449   �      c459   �      c469   �      c479   �      c489   2       c49   �      c499   �      c509         c519         c529         c539   &      c549   0      c559   :      c569   D      c579   N      c589   <       c59   X      c599   b      c609   l      c619   v      c629   �      c639   �      c649   �      c659   �      c669   �      c679   �      c689   F       c69   �      c699   �      c709   �      c719   �      c729   �      c739   �      c749   �      c759         c769         c779         c789   P       c79          c799   *      c809   4      c819   >      c829   H      c839   R      c849   \      c859   f      c869   p      c879   z      c889   Z       c89   �      c899   
       c9   �      c909   �      c919   �      c929   �      c939   �      c949   �      c959   �      c969   �      c979   �      c989   d       c99   �      c999                 6          @   @           �      @               @   @            @     @                     �          @   @           �      @               @   @            �     @                     �          @   @                 @               @   @                 @                              @   @                 @               @           @                               @   @                 @               @   @                 @                       �        @   @                 @               @   @                 @                  	             @   @                 @               @   @                 @                  	             @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                               @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     S          @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                  	             @   @                 @               @   @                 @                     W �        @   @                 @               @   @                 @                     8�        @   @                 @               @   @                 @                     W �        @   @                 @               @   @                 @                     :         @   @                 @               @   @                 @                     W �        @   @                 @               @   @                 @                  	   :         @   @                 @               @   @                 @                     W �        @   @                 @               @   @                 @                     :         @   @                 @               @   @                 @                     W �        @   @                 @               @   @                  @                     S          @   @                 @               @   @           @      @                     S          @   @                 @               @   @           �      @                     W �        @   @                 @               @   @           �      @                     8�        @   @                 @               @   @           �      @                     W �        @   @                 @               @   @           �      @                     :         @   @                 @               @   @                 @                     S �        @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     D         @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     S          @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                  	            @   @                 @               @           @                               @   @                 @               @   @            �     @                      @         @   @                 @               @   @            �     @                     W �        @   @                 @               @   @            �     @                     :         @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     S          @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                  	             @   @                 @               @   @            �     @                      �        @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     S �        @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                     W         @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                  	             @   @                 @               @   @                 @                      �        @   @                 @               @   @                 @                  	                    kompira.lic@   @                 @               @   @                 @                         @           @   �          ��������@   ����   @   @                 @   @          � �    @           @           @   @                 @             ��������@   ���������   ���������   ��������   ��������@  ���������  ���������  ��������   ��������@  ���������  ���������  ��������   ��������@  ���������  ���������  ��������d   @   @          �      @   @          ���    @   @          �      @   @          ����    @   @          �      @   @          ��     @   @          ���    @   @                 @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ���    @   @          ���     @   @          ���     @   @          �      @   @          �      @   @          ��     @   @          ��     @   @          ��     @   @          ���    @   @          ��     @   @          �      @   @                 @   @          �      @   @          �      @   @          �      @   @          ���    @   @          ���    @   @          ���    @   @          ��     @   @          ���    @   @          ��     @   @          ���    @   @          ���    @   @          ��     @   @                 @   @          ��     @   @          ��     @   @                 @   @                 @   @          ���    @   @                 @   @                 @   @          �       @   @                 @   @          ���     @   @                 @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @                 @   @                 @   @          ?       @   @                 @   @          ����    @   @                 @   @                 @   @          ���    @   @          ���     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @          ��     @   @                 @   @          ��     @   @          ?       @           @           @           @   @          ��      @           @           @           @                                                                                   d      bluetooth_socket            netlink_audit_socket         
   tcp_socket            msgq            rose_socket            binder            dir            peer            tipc_socket            blk_file            chr_file            ipc         
   ipx_socket            lnk_file            netlink_connector_socket            process            atmsvc_socket            capability2            fd         
   nfc_socket            packet            socket            bridge_socket         
   cap_userns         	   fifo_file            file            node            process2            bpf            decnet_socket            irda_socket            phonet_socket            netlink_nflog_socket         
   rds_socket            sctp_socket         
   xdp_socket            key            netlink_netfilter_socket         	   ib_socket            netlink_iscsi_socket            netlink_tcpdiag_socket            unix_stream_socket            kernel_service            netlink_route_socket            pppox_socket            ieee802154_socket            infiniband_endport            netlink_rdma_socket            netrom_socket            shm         
   llc_socket            netlink_selinux_socket         
   capability            mpls_socket            netlink_ip6fw_socket            cap2_userns            dccp_socket            iucv_socket            netlink_firewall_socket         	   sock_file            unix_dgram_socket         
   kcm_socket            netlink_kobject_uevent_socket            vsock_socket         
   filesystem            netlink_xfrm_socket            rxrpc_socket         
   can_socket            netlink_dnrt_socket            netlink_generic_socket            atmpvc_socket            ax25_socket            netlink_scsitransport_socket            service         
   x25_socket            isdn_socket         
   key_socket            netif            packet_socket         
   perf_event         
   memprotect            msg            qipcrtr_socket         
   tun_socket         
   udp_socket            appletalk_socket            netlink_crypto_socket            proxy            rawip_socket            association            caif_socket            netlink_socket            infiniband_pkey            sem            system         
   alg_socket            icmp_socket            netlink_fib_lookup_socket            security         
   smc_socket               object_r            system_r            	   file_type            httpd_sys_content_t            kompira_licence_t            etc_t            sysfs_t            tmpfs_t            non_security_file_type            memcached_t            kompira_config_t            kompira_module_t            kompira_log_t            kompira_http_content_t            httpd_modules_t            kompira_repository_t            unconfined_service_t            non_auth_file_type            cgroup_t            httpd_t            tmp_t            var_t            logfile            security_file_type            httpd_log_t         
   rabbitmq_t            kompira_secret_t            kompira_opt_t            kompira_var_t         	   var_run_t         
   configfile                       s0               c0            c10            c100            c1000            c1010            c1020            c110            c120            c130            c140            c150            c160            c170            c180            c190            c20            c200            c210            c220            c230            c240            c250            c260            c270            c280            c290            c30            c300            c310            c320            c330            c340            c350            c360            c370            c380            c390            c40            c400            c410            c420            c430            c440            c450            c460            c470            c480            c490            c50            c500            c510            c520            c530            c540            c550            c560            c570            c580            c590            c60            c600            c610            c620            c630            c640            c650            c660            c670            c680            c690            c70            c700            c710            c720            c730            c740            c750            c760            c770            c780            c790            c80            c800            c810            c820            c830            c840            c850            c860            c870            c880            c890            c90            c900            c910            c920            c930            c940            c950            c960            c970            c980            c990            c1            c1001            c101            c1011            c1021            c11            c111            c121            c131            c141            c151            c161            c171            c181            c191            c201            c21            c211            c221            c231            c241            c251            c261            c271            c281            c291            c301            c31            c311            c321            c331            c341            c351            c361            c371            c381            c391            c401            c41            c411            c421            c431            c441            c451            c461            c471            c481            c491            c501            c51            c511            c521            c531            c541            c551            c561            c571            c581            c591            c601            c61            c611            c621            c631            c641            c651            c661            c671            c681            c691            c701            c71            c711            c721            c731            c741            c751            c761            c771            c781            c791            c801            c81            c811            c821            c831            c841            c851            c861            c871            c881            c891            c901            c91            c911            c921            c931            c941            c951            c961            c971            c981            c991            c1002            c1012            c102            c1022            c112            c12            c122            c132            c142            c152            c162            c172            c182            c192            c2            c202            c212            c22            c222            c232            c242            c252            c262            c272            c282            c292            c302            c312            c32            c322            c332            c342            c352            c362            c372            c382            c392            c402            c412            c42            c422            c432            c442            c452            c462            c472            c482            c492            c502            c512            c52            c522            c532            c542            c552            c562            c572            c582            c592            c602            c612            c62            c622            c632            c642            c652            c662            c672            c682            c692            c702            c712            c72            c722            c732            c742            c752            c762            c772            c782            c792            c802            c812            c82            c822            c832            c842            c852            c862            c872            c882            c892            c902            c912            c92            c922            c932            c942            c952            c962            c972            c982            c992            c1003            c1013            c1023            c103            c113            c123            c13            c133            c143            c153            c163            c173            c183            c193            c203            c213            c223            c23            c233            c243            c253            c263            c273            c283            c293            c3            c303            c313            c323            c33            c333            c343            c353            c363            c373            c383            c393            c403            c413            c423            c43            c433            c443            c453            c463            c473            c483            c493            c503            c513            c523            c53            c533            c543            c553            c563            c573            c583            c593            c603            c613            c623            c63            c633            c643            c653            c663            c673            c683            c693            c703            c713            c723            c73            c733            c743            c753            c763            c773            c783            c793            c803            c813            c823            c83            c833            c843            c853            c863            c873            c883            c893            c903            c913            c923            c93            c933            c943            c953            c963            c973            c983            c993            c1004            c1014            c104            c114            c124            c134            c14            c144            c154            c164            c174            c184            c194            c204            c214            c224            c234            c24            c244            c254            c264            c274            c284            c294            c304            c314            c324            c334            c34            c344            c354            c364            c374            c384            c394            c4            c404            c414            c424            c434            c44            c444            c454            c464            c474            c484            c494            c504            c514            c524            c534            c54            c544            c554            c564            c574            c584            c594            c604            c614            c624            c634            c64            c644            c654            c664            c674            c684            c694            c704            c714            c724            c734            c74            c744            c754            c764            c774            c784            c794            c804            c814            c824            c834            c84            c844            c854            c864            c874            c884            c894            c904            c914            c924            c934            c94            c944            c954            c964            c974            c984            c994            c1005            c1015            c105            c115            c125            c135            c145            c15            c155            c165            c175            c185            c195            c205            c215            c225            c235            c245            c25            c255            c265            c275            c285            c295            c305            c315            c325            c335            c345            c35            c355            c365            c375            c385            c395            c405            c415            c425            c435            c445            c45            c455            c465            c475            c485            c495            c5            c505            c515            c525            c535            c545            c55            c555            c565            c575            c585            c595            c605            c615            c625            c635            c645            c65            c655            c665            c675            c685            c695            c705            c715            c725            c735            c745            c75            c755            c765            c775            c785            c795            c805            c815            c825            c835            c845            c85            c855            c865            c875            c885            c895            c905            c915            c925            c935            c945            c95            c955            c965            c975            c985            c995            c1006            c1016            c106            c116            c126            c136            c146            c156            c16            c166            c176            c186            c196            c206            c216            c226            c236            c246            c256            c26            c266            c276            c286            c296            c306            c316            c326            c336            c346            c356            c36            c366            c376            c386            c396            c406            c416            c426            c436            c446            c456            c46            c466            c476            c486            c496            c506            c516            c526            c536            c546            c556            c56            c566            c576            c586            c596            c6            c606            c616            c626            c636            c646            c656            c66            c666            c676            c686            c696            c706            c716            c726            c736            c746            c756            c76            c766            c776            c786            c796            c806            c816            c826            c836            c846            c856            c86            c866            c876            c886            c896            c906            c916            c926            c936            c946            c956            c96            c966            c976            c986            c996            c1007            c1017            c107            c117            c127            c137            c147            c157            c167            c17            c177            c187            c197            c207            c217            c227            c237            c247            c257            c267            c27            c277            c287            c297            c307            c317            c327            c337            c347            c357            c367            c37            c377            c387            c397            c407            c417            c427            c437            c447            c457            c467            c47            c477            c487            c497            c507            c517            c527            c537            c547            c557            c567            c57            c577            c587            c597            c607            c617            c627            c637            c647            c657            c667            c67            c677            c687            c697            c7            c707            c717            c727            c737            c747            c757            c767            c77            c777            c787            c797            c807            c817            c827            c837            c847            c857            c867            c87            c877            c887            c897            c907            c917            c927            c937            c947            c957            c967            c97            c977            c987            c997            c1008            c1018            c108            c118            c128            c138            c148            c158            c168            c178            c18            c188            c198            c208            c218            c228            c238            c248            c258            c268            c278            c28            c288            c298            c308            c318            c328            c338            c348            c358            c368            c378            c38            c388            c398            c408            c418            c428            c438            c448            c458            c468            c478            c48            c488            c498            c508            c518            c528            c538            c548            c558            c568            c578            c58            c588            c598            c608            c618            c628            c638            c648            c658            c668            c678            c68            c688            c698            c708            c718            c728            c738            c748            c758            c768            c778            c78            c788            c798            c8            c808            c818            c828            c838            c848            c858            c868            c878            c88            c888            c898            c908            c918            c928            c938            c948            c958            c968            c978            c98            c988            c998            c1009            c1019            c109            c119            c129            c139            c149            c159            c169            c179            c189            c19            c199            c209            c219            c229            c239            c249            c259            c269            c279            c289            c29            c299            c309            c319            c329            c339            c349            c359            c369            c379            c389            c39            c399            c409            c419            c429            c439            c449            c459            c469            c479            c489            c49            c499            c509            c519            c529            c539            c549            c559            c569            c579            c589            c59            c599            c609            c619            c629            c639            c649            c659            c669            c679            c689            c69            c699            c709            c719            c729            c739            c749            c759            c769            c779            c789            c79            c799            c809            c819            c829            c839            c849            c859            c869            c879            c889            c89            c899            c9            c909            c919            c929            c939            c949            c959            c969            c979            c989            c99            c999             ��|�#
# Directory patterns (dir)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. directory type
#




























#
# Regular file patterns (file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#




































#
# Symbolic link patterns (lnk_file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#


























#
# (Un)named Pipes/FIFO patterns (fifo_file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#


























#
# (Un)named sockets patterns (sock_file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#
























#
# Block device node patterns (blk_file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#




























#
# Character device node patterns (chr_file)
#
# Parameters:
# 1. domain type
# 2. container (directory) type
# 3. file type
#


























#
# File type_transition patterns
#
# filetrans_add_pattern(domain,dirtype,newtype,class(es),[filename])
#


#
# filetrans_pattern(domain,dirtype,newtype,class(es),[filename])
#



#
# unix domain socket patterns
#



########################################
# 
# Support macros for sets of object classes and permissions
#
# This file should only have object class and permission set macros - they
# can only reference object classes and/or permissions.

#
# All directory and file classes
#


#
# All non-directory file classes.
#


#
# Non-device file classes.
#


#
# Device file classes.
#


#
# All socket classes.
#


#
# Datagram socket classes.
# 


#
# Stream socket classes.
#


#
# Unprivileged socket classes (exclude rawip, netlink, packet).
#


########################################
# 
# Macros for sets of permissions
#

#
# Permissions to mount and unmount file systems.
#


#
# Permissions for using sockets.
# 


#
# Permissions for creating and using sockets.
# 


#
# Permissions for using stream sockets.
# 


#
# Permissions for creating and using stream sockets.
# 


#
# Permissions for creating and using sockets.
# 


#
# Permissions for creating and using sockets.
# 



#
# Permissions for creating and using netlink sockets.
# 


#
# Permissions for using netlink sockets for operations that modify state.
# 


#
# Permissions for using netlink sockets for operations that observe state.
# 


#
# Permissions for sending all signals.
#


#
# Permissions for sending and receiving network packets.
#


#
# Permissions for using System V IPC
#










########################################
#
# New permission sets
#

#
# Directory (dir)
#















#
# Regular file (file)
#


























#
# Symbolic link (lnk_file)
#














#
# (Un)named Pipes/FIFOs (fifo_file)
#















#
# (Un)named Sockets (sock_file)
#














#
# Block device nodes (blk_file)
#
















#
# Character device nodes (chr_file)
#















########################################
#
# Special permission sets
#

#
# Use (read and write) terminals
#



#
# Sockets
#



#
# Keys
#


#
# Service
#



#
# perf_event
#

#
# Specified domain transition patterns
#


# compatibility:




#
# Automatic domain transition patterns
#


# compatibility:




#
# Dynamic transition pattern
#


#
# Other process permissions
#










































































































































########################################
#
# Helper macros
#

#
# shiftn(num,list...)
#
# shift the list num times
#


#
# ifndef(expr,true_block,false_block)
#
# m4 does not have this.
#


#
# __endline__
#
# dummy macro to insert a newline.  used for 
# errprint, so the close parentheses can be
# indented correctly.
#


########################################
#
# refpolwarn(message)
#
# print a warning message
#


########################################
#
# refpolerr(message)
#
# print an error message.  does not
# make anything fail.
#


########################################
#
# gen_user(username, prefix, role_set, mls_defaultlevel, mls_range, [mcs_categories])
#


########################################
#
# gen_context(context,mls_sensitivity,[mcs_categories])
#

########################################
#
# can_exec(domain,executable)
#


########################################
#
# gen_bool(name,default_value)
#

########################################
#
# gen_cats(N)
#
# declares categores c0 to c(N-1)
#




########################################
#
# gen_sens(N)
#
# declares sensitivites s0 to s(N-1) with dominance
# in increasing numeric order with s0 lowest, s(N-1) highest
#






########################################
#
# gen_levels(N,M)
#
# levels from s0 to (N-1) with categories c0 to (M-1)
#




########################################
#
# Basic level names for system low and high
#





########################################
#
# Macros for switching between source policy
# and loadable policy module support
#

##############################
#
# For adding the module statement
#


##############################
#
# For use in interfaces, to optionally insert a require block
#


# helper function, since m4 wont expand macros
# if a line is a comment (#):

##############################
#
# In the future interfaces should be in loadable modules
#
# template(name,rules)
#


##############################
#
# In the future interfaces should be in loadable modules
#
# interface(name,rules)
#




##############################
#
# Optional policy handling
#


##############################
#
# Determine if we should use the default
# tunable value as specified by the policy
# or if the override value should be used
#


##############################
#
# Extract booleans out of an expression.
# This needs to be reworked so expressions
# with parentheses can work.



##############################
#
# Tunable declaration
#


##############################
#
# Tunable policy handling
#

/var/log/kompira(/.*)?                          system_u:object_r:kompira_log_t:s0
/var/opt/kompira(/.*)?                          system_u:object_r:kompira_var_t:s0
/var/opt/kompira/html(/.*)?                     system_u:object_r:kompira_http_content_t:s0
/var/opt/kompira/repository(/.*)?               system_u:object_r:kompira_repository_t:s0
/var/opt/kompira/kompira.lic            --      system_u:object_r:kompira_licence_t:s0
/var/opt/kompira/\.secret_key           --      system_u:object_r:kompira_secret_t:s0
/opt/kompira(/.*)?                              system_u:object_r:kompira_opt_t:s0
/opt/kompira/kompira.conf               --      system_u:object_r:kompira_config_t:s0
/opt/kompira/kompira_audit.yaml         --      system_u:object_r:kompira_config_t:s0
/opt/kompira/bin/.*                             system_u:object_r:bin_t:s0
/opt/kompira/lib/.*                             system_u:object_r:kompira_module_t:s0
/opt/kompira/ssl(/.*)?                          system_u:object_r:cert_t:s0

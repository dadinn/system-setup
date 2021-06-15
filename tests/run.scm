#!/usr/bin/env -S guile \\
-e main -s
!#

(add-to-load-path
 (dirname (current-filename)))

(use-modules
 ((common utils) #:prefix utils:)
 ;;((common deps) #:prefix deps:)
 ;;((ice-9 readline))
 ;;((ice-9 format))
 ;;((ice-9 regex) #:prefix regex:)
 ;;((ice-9 rdelim) #:prefix rdelim:)
 ;;((srfi srfi-1) #:prefix srfi1:)
 ;;((ice-9 textual-ports))
 ((ice-9 iconv))
 ((ice-9 regex) #:prefix regex:)
 ((ice-9 popen) #:prefix popen:)
 ((ice-9 expect)))

(define-macro (comment . args)
  #:nil)

(define options-spec
  `((cdrom
     (description
      "Path to cdrom ISO file")
     (value #t)
     (value-arg "PATH")
     (default
       ;;  "/home/dadinn/Downloads/isos/debian-live-10.3.0-amd64-standard.iso"
       ;; ArchLinux Syslinux bootloader is configured to write to serial port,
       ;;"/home/dadinn/Downloads/isos/archlinux-2020.01.01-x86_64.iso"
       ;; unlike other distro (like Debian)
       "/home/dadinn/Downloads/isos/debian-live-10.3.0-amd64-standard.iso")
     ;; (predicate ,(lambda (path) (file-exists? path)))
     )
    (name
     (description
      "Path to virtio hard disk file")
     (value #t)
     (value-arg "PATH")
     (default "fuckshit"))
    (sources
     (description
      "Path to sources directory containing init-instroot and bootstrap scripts (defaults to parent directory)")
     (value #t)
     (value-arg "PATH")
     (predicate
      ,(lambda (path) (utils:directory? path)))
     (default ,(dirname (dirname (current-filename)))))
    (help
     (single-char #\h)
     (description
      "This usage help..."))))

(define (not-nul? c) (not (eqv? c #\nul)))

(define (matcher pattern)
  (lambda (s eof?)
    (if (not eof?)
	;;This is needed to support matching against output with null characters
	(let ((stuff (string-filter not-nul? s)))
	  (with-output-to-file "log.txt"
	    (lambda ()
	      (display (string-append "EXPECTING: " pattern))
	      (newline)
	      (display "MATCHING AGAINST:")
	      (newline)
	      (display stuff)))
	  (regex:string-match pattern stuff))
	#f)))

(define (display-slow text port)
  ;; If Isolinux serial command speed is set too low, QEMU would truncate large strings.
  ;; https://tldp.org/HOWTO/Remote-Serial-Console-HOWTO/configure-boot-loader-syslinux.html
  ;; To workaround this we need to print long text slowly.
  (for-each
   (lambda (c)
     (display c port)
     (usleep 10000))
   (string->list text)))

(define* (run-qemu #:key name memory cdrom sources devices)
  (let ((port
	 (popen:open-pipe*
	  OPEN_BOTH
	  "qemu-system-x86_64"
	  "-enable-kvm"
	  "-m" (or memory "4096")
	  "-nographic"
	  ;;"-serial" "stdio"
	  ;;"-display" "none"
	  ;;"-smbios" "uefi=on")
	  "-cdrom" cdrom
	  "-virtfs"
	  (utils:emit-arg-alist
	   `(("local")
	     ("readonly")
	     ("path" . ,sources)
	     ("mount_tag" . "sources")
	     ("security_model" . "passthrough")))
	  "-drive"
	  (utils:emit-arg-alist
	   `(("file" . ,(utils:path "disks" (string-append name ".img")))
	     ("format" . "qcow2")
	     ("if" . "virtio")
	     ("media" . "disk"))))))
    (setvbuf port 'none)
    port))

(define (main args)
  (let* ((options (utils:getopt-extra args options-spec))
	 (name (hash-ref options 'name))
	 (cdrom-path (hash-ref options 'cdrom))
	 (sources-path (hash-ref options 'sources))
	 (sources-path (or sources-path (dirname (dirname (current-filename)))))
	 (live-username "user")
	 (live-password "live")
	 (root-dev "/dev/vda")
	 (luks-passhprase "fuckshit")
	 (help? (hash-ref options 'help)))
    (cond
     (help?
      (display
       (string-append "USAGE:

" (basename (car args)) " [OPTION...] [COMMAND...]

Start up KVM/Qemu machine to test out shit

Valid options are:

" (utils:usage options-spec)))
      (newline))
     ;; ((not cdrom-path) (error "cdrom ISO image must be specified!"))
     (else
      (when (not (file-exists? "disks"))
	(mkdir "disks"))
      (system* "qemu-img" "create" "-f" "qcow2" (string-append "disks/" name ".img") "4G")
      (let ((expect-char-proc
	     (lambda (c) (display c)))
	    (expect-port
	     (run-qemu
	      #:name name
	      #:memory "4096"
	      #:cdrom cdrom-path
	      #:sources sources-path)))
	(expect
	 ((matcher "\"Booting .* Installer with Speech Synthesis\\.\\.\\.\"")
	  (sleep 1)
	  (display "\t" expect-port)
	  (sleep 1)
	  (display " console=ttyS0" expect-port)
	  (sleep 1)
	  ;;(display-slow "\t console=ttyS0" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "debian login:")
	  (display "user" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "Password:")
	  (display "live" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "\\$ ")
	  (display "sudo -i" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "export LC_ALL=C" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "mkdir /mnt/sources" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "mount -t 9p -o ro sources /mnt/sources" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "apt update" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "apt install -y guile-2.2" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "lsblk" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "ls -la /mnt/sources/" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "/mnt/sources/init-instroot/init-instroot.scm -r /dev/vda -s 100M" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "Are you sure\\? \\(Type uppercase yes\\): ")
	  (display "YES" expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher (string-append "Enter passphrase for " root-dev "[^:]*: "))
	  (display luks-passhprase expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "Verify passphrase:")
	  (display luks-passhprase expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher (string-append "Enter passphrase for " root-dev "[^:]*: "))
	  (display luks-passhprase expect-port)
	  (newline expect-port)))
	(expect
	 ((matcher "Would you like to overwrite LUKS device with random data\\? \\[y/N\\]")
	  (newline expect-port)))
	(expect
	 ((matcher "# ")
	  (display "lsblk" expect-port)
	  (newline expect-port)))
	;; not sure if this does anything... trying to get stuff printed.
	(flush-all-ports))))))


;; Matenak mukodott Archlinux-szal:
;;==================================
;; Ujabb image nem mukodott, de ezzel igen:
;; https://archive.archlinux.org/iso/2020.01.01/
;;
;; a parancs amivel futtatta:
;;
;; qemu-system-x86_64 --enable-kvm -cdrom archlinux-2020.01.01-x86_64.iso -m 512 -serial stdio -display none
;; amikor grub menu feljon TAB majd a kernel argumentumok vegere "console=ttyS0'
;; loginnal root user password nelkul bejelentkezik


;; ISO image manipullalas:
;;=========================
;; mkdir /mnt/debiso
;; mount -o loop debian-xyz.iso /mnt/debiso
;; rsync -av /mnt/debiso /tmp/debisobackup





  ;; OLD SHIT

(comment

 (comment
 (let ((port (open-pipe* OPEN_BOTH "cat")))
   (setvbuf port 'line 10)
   (display "FUCK\n" port)  
   (let ((res (read-string port))) (display res) (close port) res)))


 (system* "qemu-img" "create" "-f" "qcow" name "4G")
 
 (let ((port (popen:open-pipe* OPEN_BOTH
			       "qemu-system-x86_64"
			       "-enable-kvm"
			       "-m" "4096"
			       ;; "-drive" (string-append "file=" cdrom-path)
			       "-cdrom" cdrom-path
			       "-serial" "stdio"
			       ;;"-append" "console=ttyS0"
			       ;;"-nographic"
			       "-display" "none"
			       ;;"-smbios" "uefi=on"
			       )))
   (display "Hello world!!!")
   (while #t (display (get-line port)))

   (with-input-from-port port
     (lambda ()
       (with-output-to-port port
	 (lambda ()
	   (expect-strings
	    ("Press [Tab] to edit options"
	     (display "\t console=ttyS0")
	     (newline))))))))

 ;; this seems to work!!!
 (execlp
  "qemu-system-x86_64"
  "--enable-kvm"
  "-name" "TEST"
  "-cdrom" cdrom-path
  "-m" "512"
  "-serial" "stdio"
  ;;"-append" "console=ttyS0"
  ;;"-nographic"
  "-display" "none"
  )
 ;; After this, press tab in the GRUB ncurses choice window, and enter console=ttyS0, and press Enter
 ;; When asked for the "archiso login:" prompt type root, and Enter



 ;;these below don't work
 (execlp
  "qemu-system-x86_64"
  "-enable-kvm"
  "-m" "4096"
  ;; "-drive" (string-append "file=" cdrom-path)
  "-cdrom" cdrom-path
  "-serial" "stdio"
  "-append" "console=ttyS0" ;; THIS CAN'T work
  "-nographic"
  ;;"-smbios" "uefi=on"
  )

 (system*
  "virt-install"
  ;;"--connect" "qemu:///system"
  "--connect" "qemu:///session"
  "--name" name
  "--description" "testing system installation"
  "--ram" "4096"
  "--vcpu" "2"
  ;;"--os-type" "linux"
  ;;"--os-variant" "Debian10"
  "--cdrom" "/home/dadinn/Downloads/isos/debian-live-10.3.0-amd64-standard.iso"
  ;; ISO image doesn't seem to work with location
  ;;"--location" "/home/dadinn/Downloads/isos/debian-live-10.3.0-amd64-standard.iso"
  ;;"--location" "http://ftp.us.debian.org/debian/dists/buster/main/installer-amd64/"
  ;;"--extra-args" "console=tty0,115200n8,serial,systemd.unit=multi-user.target"
  ;;"--extra-args" "console=ttyS0"
  "--disk" (string-append "path=disks/" name ".img,bus=virtio,size=4")
  "--filesystem" (string-append sources-path ",sources")
  ;;"--boot" "uefi"
  "--graphics" "none"
  "--serial" "stdio"
  "--debug"
  ;; this is not working with forced poweroff
  ;;"--events" "on_poweroff=destroy"
  ))

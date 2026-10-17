# Desktop VMs: libvirt + QEMU/KVM with virt-manager (2026-10-17, for a Kali
# guest). Hardware was already there — kvm-amd is loaded by the hardware scan
# and /dev/kvm exists — only the userspace was missing. Images default to
# /var/lib/libvirt/images on the root filesystem; both / and /data are >90%
# full, so give guests sparse qcow2 disks and watch `df` before adding more.
{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;          # TPM device for guests that want one
      # QEMU now supplies its OVMF UEFI images by default.
    };
  };
  programs.virt-manager.enable = true;   # GUI; `virsh` / `virt-install` come with libvirt
  virtualisation.spiceUSBRedirection.enable = true;   # pass USB devices (Wi-Fi adapters etc.) to the guest

  # Default NAT network ("default", virbr0) so guests get internet without
  # bridging the host's NIC. Autostart it once libvirtd is up.
  systemd.services.libvirtd.postStart = ''
    ${pkgs.libvirt}/bin/virsh net-autostart default >/dev/null 2>&1 || true
    ${pkgs.libvirt}/bin/virsh net-start default >/dev/null 2>&1 || true
  '';
}

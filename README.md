# ProjectProto for Qualcomm MSM8916 devices

ProjectProto is a microSD repartitioning solution for Qualcomm MSM8916 devices. It provides different partition layouts depending on the intended use case.

## Why ProjectProto?

On Samsung devices based on Qualcomm MSM8916, it is not possible to modify the partition table on the internal (eMMC) storage, regardless of the tool or method used. Whether attempting to delete, create, or modify partitions, tools will not report any errors and will appear to succeed but no actual changes will be made. In some cases even the contents of certain partitions cannot be modified, leaving users with limited options for customization. The root cause of this behavior is unclear but it is believed to be a combination of Qualcomm's and the OEM's proprietary security and protection mechanisms.

### Why is this an issue?

For users and developers who want to perform more advanced customization on their devices these limitations can be very frustrating. The inability to modify the partition table directly on the eMMC restricts the flexibility of the device, especially for tasks such as:

- Expanding partition sizes to accommodate larger, more modern versions of Android OS.
- Repartitioning to enable Android Treble support, which requires a dedicated vendor partition.

### How does ProjectProto solve this problem?

ProjectProto clones the entire eMMC storage (including all existing partitions) to the microSD card using the `dd` utility. After cloning, the system, cache, hidden, and userdata partitions on the microSD card will be removed and recreated using `sgdisk` and `blockdev` to adjust the partition layout. The protection mechanisms on eMMC do not apply to microSD cards which allows the partition layout on the microSD card to be modified freely.

ProjectProto Lite leaves the eMMC untouched and creates only a dedicated vendor partition by repartitioning the microSD card from scratch, leaving the remaining space available as external storage.

> [!NOTE]
> Only partitions are being cloned. Hardware-bound blocks e.g. Replay Protected Memory (`/dev/block/mmcblk0rpmb`) cannot be cloned.

### Partition layout changes on the microSD card

#### Regular variant
- The system partition will be resized to 3.5 GiB. The partition label will be renamed to `SYSTEM` (uppercase) to prevent boot issues with ROMs installed on internal storage that use Android's early mounting system.
- The cache and hidden partitions will retain their original sizes. Repartitioning is required because the system partition precedes them and will be expanded.
- A new vendor partition with a size of 700 MiB will be created. To preserve the original partition order, the vendor partition is placed after the userdata partition.
- All remaining available sectors will be assigned to the userdata partition.

This repartitioning allows the installation of larger, especially 64-bit based Android OS. The addition of a dedicated vendor partition also prepares the device for Android Treble compatibility.

#### Lite variant
- The first partition will use the majority of the available space and will be labeled `external`, serving as the primary storage partition.
- A second partition with a size of 700 MiB will be created as vendor after the external partition.

This repartitioning keeps the microSD card usable as an external storage device while adding a dedicated vendor partition for Android Treble compatibility.

## Requirements

A fully functional microSD card slot is essential to use ProjectProto. However, additional requirements depend on the variant.

### Regular variant
- TWRP Recovery with the following tools included: `dd`, `sgdisk`, `blockdev`, `awk`, `mke2fs`
- A microSD card of 16 GB or larger, providing enough space to hold the entire eMMC storage

Recommended: At least a 32 GB microSD card with Class 10, UHS-I (U3), V30, A1, or better specifications.

> [!IMPORTANT]
> The performance of the microSD card directly affects ROM performance. Cards slower than the recommended specifications may result in poor ROM performance and a bad user experience.

### Lite variant
- TWRP Recovery with the following tools included: `sgdisk`, `blockdev`, `awk`, `mkexfatfs`, `mke2fs`
- A microSD card of 2 GB or larger (Class 10 or better)

## Installation
To preserve the modularity of ProjectProto, a single monolithic shell script was avoided. Instead the core operations were split into multiple shell script files. This approach ensures compatibility not only with shell-based installation scripts but also with (aroma) updater scripts used in TWRP Recovery.

> [!WARNING]
> Installing either ProjectProto variant completely repartitions the microSD card. All existing partitions and data on the microSD card will be lost. Back up any important data before installation.

### Flashable
Standalone flashable ZIP packages are available in this repository's [Releases](https://github.com/prototype74/ProjectProto-msm8916/releases).

1. Download the latest release.
2. Copy the ZIP file to your internal storage (not microSD card!).
3. Boot into TWRP Recovery.
4. Tap `Install` and select the downloaded ZIP file.
5. Swipe to flash.

### Manual

1. Boot into TWRP Recovery
2. Create a new directory `scripts` in `/tmp`:
    ```shell
    mkdir -p /tmp/scripts
    ```
3. Copy all shell script files from this repository to `/tmp/scripts` on your MSM8916 device
4. Set the required permissions:
    ```shell
    chmod 0755 /tmp/scripts/*
    ```
5. Run the installer for the desired variant:

    **Regular:**
    ```shell
    sh /tmp/scripts/install.sh
    ```
    **Lite:**
    ```shell
    sh /tmp/scripts/install_lite.sh
    ```
---
> [!IMPORTANT]
> - The installation speed depends on the specifications of the microSD card.
> - Do <b>not</b> remove the microSD card during installation!
> - Reboot to recovery after the installation to apply all changes.

## Booting from microSD card (Regular variant only)

The boot process depends on whether the device has a functional eMMC. If this is the case, the MSM8916 will always boot from the eMMC, regardless of whether ProjectProto is installed. To boot the Android OS from the microSD card, the kernel command line parameter `android.bootdevice` in the kernel image must be changed from `7824900.sdhci` to `7864900.sdhci`. This will lead the kernel to mount all partitions using `/dev/block/bootdevice/*` from the microSD card instead of the eMMC. If the kernel's device tree includes an Android fstab (e.g. for early mounting), the corresponding SDHCI paths must also be updated there.

### Mounting the system partition from microSD
Since the label of the system partition on the microSD card has been changed after repartitioning, the corresponding entries in the kernel's device tree or in the kernel ramdisk's fstab, which attempt to mount the system partition, must also be adjusted accordingly. The following instructions refer to general adjustments and may vary depending on the kernel configuration:

- On Android 7.1 or earlier, update `fstab.qcom` in the kernel's ramdisk:
    ```diff
    -/dev/block/bootdevice/by-name/system   /system   ext4   ro,errors=panic,noload,block_validity   wait
    +/dev/block/bootdevice/by-name/SYSTEM   /system   ext4   ro,errors=panic,noload,block_validity   wait
    ```

- On Android 8.0 and later, update the kernel's device tree:
    ```diff
    firmware {
        android {
            compatible = "android,firmware";
            fstab {
                compatible = "android,fstab";
                system {
                    compatible = "android,system";
    -               dev = "/dev/block/platform/soc.0/7824900.sdhci/by-name/system";
    +               dev = "/dev/block/platform/soc.0/7864900.sdhci/by-name/SYSTEM";
                    type = "ext4";
                    mnt_flags = "ro,barrier=1,discard";
                    fsmgr_flags = "wait";
                    status = "ok";
                };
            };
        };
    };
    ```

---

With these changes applied, the boot process proceeds as follows:

![working_emmc](assets/working_emmc.jpg)

> [!WARNING]
> Make sure to remove the microSD card entry from Android's fstab, otherwise the ramdisk may attempt to mount the first partition (APNHLOS) as external storage, incorrectly treating it as usable storage.

### Boot process with a corrupted or failed eMMC

If the eMMC becomes corrupted or fails for any reason, the MSM8916 may attempt to boot from the microSD card instead. Since ProjectProto clones all eMMC partitions to the microSD card, the MSM8916 can load the Secondary Bootloader (SBL) and the Android Bootloader (ABOOT) from the microSD card even if the eMMC has failed:

![failed_emmc](assets/failed_emmc.jpg)

This means that ProjectProto may prevent a complete device failure that would otherwise leave the device stuck in EDL mode (QDLoader 9008). However, it is not guaranteed that the Primary Bootloader (PBL) will fall back to the microSD card, as this highly depends on the boot configuration implemented in the PBL.

Therefore, ROM developers are advised to install the kernel image on both the eMMC and the microSD boot partitions. This ensures that the ROM remains bootable from the microSD card in case the PBL falls back to it during the boot process.

## Supported devices

### Regular variant
The following devices are supported by the Regular variant:

- <b>Galaxy A3 2015</b>: SM-A300FU, SM-A300Y
- <b>Galaxy Ace 4</b>: SM-G357FZ
- <b>Galaxy J5 2015</b>: SM-J500F, SM-J500FN, SM-J500G, SM-J500H, SM-J500M, SM-J500N0, SM-J500Y
- <b>Galaxy J5 2016</b>: SM-J510F, SM-J510FN, SM-J510FQ, SM-J510GN, SM-J510H, SM-J510K, SM-J510L, SM-J510MN, SM-J510S, SM-J510UN

### Lite variant
ProjectProto Lite is **not restricted** to the devices listed above. It is designed to work with Android devices based on Qualcomm MSM8916.

## License

ProjectProto is licensed under the MIT License

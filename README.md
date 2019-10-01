# backup-restore

## LICENSE

   backup-restore.sh - disk backup and restoration from command line

   (c) 2019 Luc Deschenaux <luc.deschenaux@freesurf.ch>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Affero General Public License for more details.

   You should have received a copy of the GNU Affero General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Usage

 The file name (or symbolic link name) of this script is the entry point.
 eg if you can create links with:
 ```
  ln -s backup-restore.sh backup_device
  ln -s backup-restore.sh select_and_restore_image

 ```
 then you can run from the command line:
 ```
  backup_device /dev/sda1 /dev/sdb1 
  backup_device /dev/sda1 //server/share
  select_and_restore_image /dev/sda1 /dev/nvme0n1
  select_and_restore_image //serve/share /dev/nvme0n1 
 ```

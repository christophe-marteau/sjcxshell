SJCX Shell
==========

Shell to manipulate storj files with Metadisk API.

#### Features
 - Adding user
 - List files and buckets
 - Create and delete buckets
 - Copy files
 - Delete files

### Installation instructions

#### Dependencies

On ubuntu, you need to install these packages :
```bash
apt-get install bash man mawk curl openssl python3 python3-websocket
```

#### Installation

Just clone SJCX Shell in a folder and update "etc/sjcx.conf" settings.

You need at least to modify "SJCXSHELL_PATH" according to your installation path.

If you don't want colored folder output, just set "ACTIVE_FOLDER_COLOR" and "INACTIVE_FOLDER_COLOR" to "7"

#### Configuration

You can modify settings in "etc/sjcx.conf"

Especially if you use a different distribution you should modify "*_BINARY" settings to fit with your system.

### Usage

For using sjcxshell, you need to create an account on the metadisk API.

#### Create an account

Firt you need you need to create a user with an email and a password:
```bash
./sjcxadduser -e user@example.org -p myPassword
[info] (sjcxadduser) User created with id 'user@example.org' at '2016-04-03T19:40:39.062Z' ( Activation state : 'false' )
```

Once created you have to check your mails and activate your account by following the activation URL.

**Note:** If you have already a registered and activated user account you must create a user anyway with the -o option :
```bash
./sjcxadduser -o -e user@example.org -p myPassword
[info] (sjcxadduser) User created localy with id 'user@example.org'
```

#### Using sjcxshell

In order to use sjcxshell, simply use this command with your registered user email :
```bash
./sjcxshell -u user@example.org
sjcx [user@example.org]>
```

All sjcxshell functions begin with "sjcx" so you can use tab to list availables functions or use minihelp command.
```bash
sjcx [user@example.org]> minihelp
```

To display all full help, use the help command :
```bash
sjcx [user@example.org]> help
```

### Notes
This software as only been tested on ubuntu 15.10 but may work with other distributions.

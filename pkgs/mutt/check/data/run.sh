# builds a two-message mbox with fixed names and dates, then runs mutt on it
export TZ=UTC HOME="$PWD" LANG=C
cat > muttrc <<'RC'
set folder="."
set tmpdir="."
set mbox_type=mbox
set sort=date
set realname="Tester"
set from="tester@example.com"
set hostname="example.com"
set use_domain=no
set help=no
set wait_key=no
set mark_old=no
set sleep_time=0
set mail_check=0
set timeout=0
set pager_index_lines=0
RC
cat > mbox <<'MB'
From alice@example.com Wed Jan  1 00:00:00 2020
From: Alice <alice@example.com>
To: Tester <tester@example.com>
Subject: First message
Date: Wed, 1 Jan 2020 00:00:00 +0000
Message-ID: <1@example.com>

Hello one.
Second line of one.

From bob@example.com Thu Jan  2 12:00:00 2020
From: Bob <bob@example.com>
To: Tester <tester@example.com>
Subject: Second message
Date: Thu, 2 Jan 2020 12:00:00 +0000
Message-ID: <2@example.com>

Hello two.

MB
exec mutt -n -R -F muttrc -f mbox "$@"

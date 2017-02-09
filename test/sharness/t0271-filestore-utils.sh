#!/bin/sh
#
# Copyright (c) 2017 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="Test out the filestore nocopy functionality"

. lib/test-lib.sh


test_init_dataset() {
	test_expect_success "create a dataset" '
		rm -r somedir
		mkdir somedir &&
		random    1000  1 > somedir/file1 &&
		random   10000  2 > somedir/file2 &&
		random 1000000  3 > somedir/file3
	'
}

EXPHASH="QmRueCuPMYYvdxWz1vWncF7wzCScEx4qasZXo5aVBb1R4V"

cat <<EOF > ls_expect
zb2rhaPkR7ZF9BzSC2BfqbcGivi9QMdauermW9YB6NvS7FZMo   10000 somedir/file2 0
zb2rhav4wcdvNXtaKDTWHYAqtUHMEpygT1cxqMsfK7QrDuHxH  262144 somedir/file3 524288
zb2rhbcZ3aUXYcrbhhDH1JyrpDcpdw1KFJ5Xs5covjnvMpxDR    1000 somedir/file1 0
zb2rhe28UqCDm7TFib7PRyQYEkvuq8iahcXA2AbgaxCLvNhfk  262144 somedir/file3 0
zb2rhebtyTTuHKyTbJPnkDUSruU5Uma4DN8t2EkvYZ6fP36mm  262144 somedir/file3 262144
zb2rhm9VTrX2mfatggYUk8mHLz78XBxVUTTzLvM2N3d6frdAU  213568 somedir/file3 786432
EOF

FILE1_HASH=zb2rhbcZ3aUXYcrbhhDH1JyrpDcpdw1KFJ5Xs5covjnvMpxDR
FILE2_HASH=zb2rhaPkR7ZF9BzSC2BfqbcGivi9QMdauermW9YB6NvS7FZMo
FILE3_HASH=QmfE4SDQazxTD7u8VTYs9AJqQL8rrJPUAorLeJXKSZrVf9

cat <<EOF > verify_expect
ok      zb2rhaPkR7ZF9BzSC2BfqbcGivi9QMdauermW9YB6NvS7FZMo   10000 somedir/file2 0
ok      zb2rhav4wcdvNXtaKDTWHYAqtUHMEpygT1cxqMsfK7QrDuHxH  262144 somedir/file3 524288
ok      zb2rhbcZ3aUXYcrbhhDH1JyrpDcpdw1KFJ5Xs5covjnvMpxDR    1000 somedir/file1 0
ok      zb2rhe28UqCDm7TFib7PRyQYEkvuq8iahcXA2AbgaxCLvNhfk  262144 somedir/file3 0
ok      zb2rhebtyTTuHKyTbJPnkDUSruU5Uma4DN8t2EkvYZ6fP36mm  262144 somedir/file3 262144
ok      zb2rhm9VTrX2mfatggYUk8mHLz78XBxVUTTzLvM2N3d6frdAU  213568 somedir/file3 786432
EOF

test_filestore_adds() {
	test_expect_success "nocopy add succeeds" '
		HASH=$(ipfs add --raw-leaves --nocopy -r -q somedir | tail -n1)
	'

	test_expect_success "nocopy add has right hash" '
		test "$HASH" = "$EXPHASH"
	'

	test_expect_success "'ipfs filestore ls' output looks good'" '
		ipfs filestore ls | LC_ALL=C sort > ls_actual &&
		test_cmp ls_expect ls_actual
	'

	test_expect_success "'ipfs filestore ls HASH' works" '
		ipfs filestore ls $FILE1_HASH > ls_actual &&
		grep -q somedir/file1 ls_actual
	'

	test_expect_success "can retrieve multi-block file" '
		ipfs cat $FILE3_HASH > file3.data &&
		test_cmp somedir/file3 file3.data
	'
}

test_filestore_verify() {
	test_expect_success "ipfs filestore verify' output looks good'" '
		ipfs filestore verify | LC_ALL=C sort > verify_actual
		test_cmp verify_expect verify_actual
	'

	test_expect_success "'ipfs filestore verify HASH' works" '
		ipfs filestore verify $FILE1_HASH > verify_actual &&
		grep -q somedir/file1 verify_actual
	'

	test_expect_success "rename a file" '
		mv somedir/file1 somedir/file1.bk
	'

	test_expect_success "can not retrieve block after backing file moved" '
		test_must_fail ipfs cat $FILE1_HASH
	'

	test_expect_success "'ipfs filestore verify' shows file as missing" '
		ipfs filestore verify > verify_actual &&
		grep no-file verify_actual | grep -q somedir/file1
	'

	test_expect_success "move file back" '
		mv somedir/file1.bk somedir/file1
	'

	test_expect_success "block okay now" '
		ipfs cat $FILE1_HASH > /dev/null
	'

	test_expect_success "change first bit of file" '
		dd if=/dev/zero of=somedir/file3 bs=1024 count=1
	'

	test_expect_success "can not retrieve block after backing file changed" '
		test_must_fail ipfs cat $FILE3_HASH
	'

	test_expect_success "'ipfs filestore verify' shows file as changed" '
		ipfs filestore verify > verify_actual &&
		grep changed verify_actual | grep -q somedir/file3
	'
}

cat <<EOF > dups_expect
$FILE1_HASH
EOF

test_filestore_dups_rm() {
	test_expect_success "'ipfs filestore dups'" '
		ipfs add --raw-leaves somedir/file1 &&
		ipfs filestore dups > dups_actual &&
		test_cmp dups_expect dups_actual
	'

	test_expect_success "remove non-filestore block of dup ok" '
		ipfs filestore rm --non-filestore $FILE1_HASH &&
		ipfs filestore dups > dups_actual &&
		test_cmp /dev/null dups_actual
	'

	test_expect_success "block still in filestore" '
		ipfs filestore ls $FILE1_HASH | grep -q file1
	'

	test_expect_success "remove non-duplicate pinned block not ok" '
		test_must_fail ipfs filestore rm $FILE1_HASH 2> rm_err &&
		grep -q pinned rm_err
	'

	test_expect_success "remove filestore block of dup ok" '
		ipfs add --raw-leaves somedir/file1 &&
		ipfs filestore rm $FILE1_HASH &&
		ipfs filestore dups > dups_actual &&
		test_cmp /dev/null dups_actual
	'
}

init_ipfs_filestore() {
	test_expect_success "clean up old node" '
		rm -rf "$IPFS_PATH" mountdir ipfs ipns
	'

	test_init_ipfs

	test_expect_success "enable filestore config setting" '
		ipfs config --json Experimental.FilestoreEnabled true
	'
}

test_init_dataset

init_ipfs_filestore

test_filestore_adds

test_filestore_verify

test_filestore_dups_rm

echo "WORKING DIR"
echo "IPFS PATH = " $IPFS_PATH
pwd


test_init_dataset

init_ipfs_filestore

# must be in offline mode so tests of retrieving non-exist blocks
# don't hang
test_launch_ipfs_daemon --offline

test_filestore_adds

test_filestore_verify

test_filestore_dups_rm

test_kill_ipfs_daemon

test_done

package posinfo

import (
	"os"

	node "gx/ipfs/QmNXjLb18Tx1nvXYjYHs6TTBEVjP8WSYVNuTDioSkyVaSN/go-ipld-node"
)

type PosInfo struct {
	Offset   uint64
	FullPath string
	Stat     os.FileInfo // can be nil
}

type FilestoreNode struct {
	node.Node
	PosInfo *PosInfo
}

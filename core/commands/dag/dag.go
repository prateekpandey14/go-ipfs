package dagcmd

import (
	"fmt"
	"io"
	"strings"

	cmds "github.com/ipfs/go-ipfs/commands"
	path "github.com/ipfs/go-ipfs/path"

	"github.com/ipfs/go-ipfs-cmds/cmdsutil"

	node "gx/ipfs/QmRSU5EqqWVZSNdbU51yXmVoF1uNw3JgTNB6RaiL7DZM16/go-ipld-node"
	cid "gx/ipfs/QmcTcsTvfaeEBRFo1TkFgT8sRmgi1n1LTZpecfVP8fzpGD/go-cid"
	ipldcbor "gx/ipfs/QmfMxth6d2po8YGrtSVyNb2u6SFNrPdAsWQoZG83oXRBqX/go-ipld-cbor"
)

var DagCmd = &cmds.Command{
	Helptext: cmdsutil.HelpText{
		Tagline: "Interact with ipld dag objects.",
		ShortDescription: `
'ipfs dag' is used for creating and manipulating dag objects.

This subcommand is currently an experimental feature, but it is intended
to deprecate and replace the existing 'ipfs object' command moving forward.
		`,
	},
	Subcommands: map[string]*cmds.Command{
		"put": DagPutCmd,
		"get": DagGetCmd,
	},
}

type OutputObject struct {
	Cid *cid.Cid
}

var DagPutCmd = &cmds.Command{
	Helptext: cmdsutil.HelpText{
		Tagline: "Add a dag node to ipfs.",
		ShortDescription: `
'ipfs dag put' accepts input from a file or stdin and parses it
into an object of the specified format.
`,
	},
	Arguments: []cmdsutil.Argument{
		cmdsutil.FileArg("object data", true, false, "The object to put").EnableStdin(),
	},
	Options: []cmdsutil.Option{
		cmdsutil.StringOption("format", "f", "Format that the object will be added as.").Default("cbor"),
		cmdsutil.StringOption("input-enc", "Format that the input object will be.").Default("json"),
	},
	Run: func(req cmds.Request, res cmds.Response) {
		n, err := req.InvocContext().GetNode()
		if err != nil {
			res.SetError(err, cmdsutil.ErrNormal)
			return
		}

		fi, err := req.Files().NextFile()
		if err != nil {
			res.SetError(err, cmdsutil.ErrNormal)
			return
		}

		ienc, _, _ := req.Option("input-enc").String()
		format, _, _ := req.Option("format").String()

		switch ienc {
		case "json":
			nd, err := convertJsonToType(fi, format)
			if err != nil {
				res.SetError(err, cmdsutil.ErrNormal)
				return
			}

			c, err := n.DAG.Add(nd)
			if err != nil {
				res.SetError(err, cmdsutil.ErrNormal)
				return
			}

			res.SetOutput(&OutputObject{Cid: c})
			return
		default:
			res.SetError(fmt.Errorf("unrecognized input encoding: %s", ienc), cmdsutil.ErrNormal)
			return
		}
	},
	Type: OutputObject{},
	Marshalers: cmds.MarshalerMap{
		cmds.Text: func(res cmds.Response) (io.Reader, error) {
			oobj, ok := res.Output().(*OutputObject)
			if !ok {
				return nil, fmt.Errorf("expected a different object in marshaler")
			}

			return strings.NewReader(oobj.Cid.String()), nil
		},
	},
}

var DagGetCmd = &cmds.Command{
	Helptext: cmdsutil.HelpText{
		Tagline: "Get a dag node from ipfs.",
		ShortDescription: `
'ipfs dag get' fetches a dag node from ipfs and prints it out in the specifed format.
`,
	},
	Arguments: []cmdsutil.Argument{
		cmdsutil.StringArg("ref", true, false, "The object to get").EnableStdin(),
	},
	Run: func(req cmds.Request, res cmds.Response) {
		n, err := req.InvocContext().GetNode()
		if err != nil {
			res.SetError(err, cmdsutil.ErrNormal)
			return
		}

		p, err := path.ParsePath(req.Arguments()[0])
		if err != nil {
			res.SetError(err, cmdsutil.ErrNormal)
			return
		}

		obj, err := n.Resolver.ResolvePath(req.Context(), p)
		if err != nil {
			res.SetError(err, cmdsutil.ErrNormal)
			return
		}

		res.SetOutput(obj)
	},
}

func convertJsonToType(r io.Reader, format string) (node.Node, error) {
	switch format {
	case "cbor", "dag-cbor":
		return ipldcbor.FromJson(r)
	case "dag-pb", "protobuf":
		return nil, fmt.Errorf("protobuf handling in 'dag' command not yet implemented")
	default:
		return nil, fmt.Errorf("unknown target format: %s", format)
	}
}

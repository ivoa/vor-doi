"""
A python script turning an ivo_vor OAI-PMH response into a set of datacite
records.

This works both as a command line tool and from within other scripts.
See the DataciteInterface for use from your own code.

The conversion is essentially just the application of an XSL stylesheet,
except:

(1) we're trying to figure out if creator/name is actually several
names mangled together, in which case we're unmangling them
(2) the DOI needs to come from somewhere

For (2), there's a bit of code built in that might work for you (we're
simply taking MD5 hashes of the ivoids, base64-encode them and use that
as resource key.  This will sooner or later collide, but you might well
decide that the "later" is late enough for you.

See also http://test.datacite.org

Dependencies: python-lxml2, python-requests
"""

import base64
import hashlib
import sys
import urllib.parse

import requests
from lxml import etree

OAI_ENDPOINT = "http://dc.g-vo.org/rr/q/pmh/pubreg.xml"

RI_NS = "http://www.ivoa.net/xml/RegistryInterface/v1.0"
DC_NS = "http://datacite.org/schema/kernel-4"


def etree_QName(ns, tag):
# Due to an lxml bug (3.4.0-1 in Debian), I need this workaround.  Remove
# when that library is history and rename etree_QName to etree.QName
	return etree.QName(ns, tag).text


class DataciteInterface(object):
	"""a facade to transforming VOResource records and uploading them
	to datacite.

	It allows the central configuration of many of the central parameters.
	Defaults are provided for just trying things out.  These will not work
	in production.

	In particular, you must
	* obtain your own DOI prefix.
	* change the datacite_endpoint to an operational one
	* probably fix the path to the XSLT source
	* provide the credentials (currently as auth as suitable for requests.post)

	Once you have that, work this facade as follows:

	(1) doi = d.get_DOI(ivoid)
	(2) make sure doi is doesn't collide
	(3) datacite_tree = d.tranlate(parsed_dc_record, doi)
	(4) d.upload(datacite_tree, dest_uri)

	-- where dest_uri is an appropriate landing page.
	"""
	def __init__(self, doi_prefix="10.5072",
			datacite_endpoint="https://mds.test.datacite.org",
			xslt_source="vor-to-doi.xslt",
			auth=None):
		self.doi_prefix, self.datacite_endpoint = doi_prefix, datacite_endpoint
		self.transform = etree.XSLT(etree.parse(xslt_source))
		self.auth = auth

	def get_DOI(self, rec_id):
		"""returns a DOI for rec_id.

		Don't use this without checking for collisions externally.
		"""
		doi = self.doi_prefix+"/"+base64.b64encode(
			hashlib.md5(rec_id.encode("utf-8"),
			).digest(), altchars=b"_:").decode("ascii").strip().rstrip("=")
		return doi

	def upload(self, datacite_tree, landingpage_uri):
		"""uploads the datacite core metadata in the etree datacite_tree and
		sets the resolved URI to landingpage_uri.
		"""
		doi = datacite_tree.xpath("//d:identifier[@identifierType='DOI']",
			namespaces={'d': DC_NS})[0].text

		# First, upload the metadata
		response = requests.post(self.datacite_endpoint+"/metadata",
			auth=self.auth,
			data=str(datacite_tree).encode("utf-8"),
			headers={'content-type': 'application/xml'})
		response.raise_for_status()

		# then, link the the DOI with our landing page
		response = requests.post(
			self.datacite_endpoint+"/doi",
			auth=self.auth,
			data=("doi=%s\r\nurl=%s"%(doi, landingpage_uri)).encode("utf-8"),
			headers={'content-type': 'text/plain;charset=UTF-8'})
		response.raise_for_status()

	def translate(self, rec, get_doi_for_ivoid):
		"""returns an IVOID and the etree of datacite metadata for a
		VOResource record rec.

		get_doi_for_ivoid is a function receiving the ivoid and returning a DOI
		to use.
		"""
		rec_id = rec.xpath("//identifier")[0].text
		doi = get_doi_for_ivoid(rec_id)
		datacite_tree = self.transform(rec, doi_for_record="'%s'"%doi)
		return rec_id, datacite_tree


def parse_command_line():
	import argparse
	parser = argparse.ArgumentParser(description="Turn a VOResource OAI-PMH"
		" GetRecords response into a set of Datacite Core metadata pieces"
		" and optionally upload them.")
	parser.add_argument("-u", "--upload-with", dest="upload_auth",
		help="username:password credentials for upload to DC_HOST.",
		default=None)
	parser.add_argument("source_name", help="Source file to read from."
		"  Omit to make the program read from stdin", nargs="?",
		default=None)

	args = parser.parse_args()

	if args.upload_auth:
		args.upload_auth = tuple(args.upload_auth.split(":", 1))
	return args


def main():
	args = parse_command_line()
	if args.source_name:
		in_file = open(args.source_name)
	else:
		in_file = sys.stdin

	sys.stderr.write("Testing/Evaluation.  Do not use in production.\n")
	intf = DataciteInterface(auth=args.upload_auth)

	tree = etree.parse(in_file)

	for count, rec in enumerate(
			tree.iter(tag=etree_QName(RI_NS, "Resource"))):
		
		ivoid, datacite_rec = intf.translate(rec, intf.get_DOI)

		if args.upload_auth:
			dest_uri = OAI_ENDPOINT+(
				"?verb=GetRecord&metadataPrefix=ivo_vor&identifier=%s"%
				urllib.parse.quote(ivoid))
			intf.upload(datacite_rec, dest_uri)
			sys.stderr.write("Uploaded %s\n"%ivoid)
		else:
			with open("datacite_%04d.datacite"%count, "w") as f:
				f.write(str(datacite_rec))


if __name__=="__main__":
	main()

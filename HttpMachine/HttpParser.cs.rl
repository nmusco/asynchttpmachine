using System;
using System.Text;

namespace HttpMachine
{
    public class HttpParser
    {
        int cs;
        int mark;
        int qsMark;
        int fragMark;
        IHttpParserHandler parser;

		// ew!
		StringBuilder sb;
		StringBuilder sb2;

		int versionMajor;
		int versionMinor;

		public int MajorVersion { get { return versionMajor; } }
		public int MinorVersion { get { return versionMinor; } }
		
		bool inContentLengthHeader;
		bool inConnectionHeader;
		bool inTransferEncodingHeader;
		bool inUpgradeHeader;

		bool gotConnectionClose;
		bool gotConnectionKeepAlive;
		bool gotTransferEncodingChunked;
		bool gotUpgradeValue;

        int contentLength;

		public bool ShouldKeepAlive { 
			get { 
				if (versionMajor > 0 && versionMinor > 0)
					// HTTP/1.1
					return !gotConnectionClose;
				else 
					// < HTTP/1.1
					return gotConnectionKeepAlive;
			}
		}


        %%{

        # define actions
        machine http_parser;

		action buf {
			sb.Append((char)fc);
		}

		action clear {
			sb.Length = 0;
		}

		action buf2 {
			sb2.Append((char)fc);
		}

		action clear2 {
			if (sb2 == null)
				sb2 = new StringBuilder();
			sb2.Length = 0;
		}

		action message_begin {
			//Console.WriteLine("message_begin");
			versionMajor = 0;
			versionMinor = 9;
<<<<<<< HEAD
			inConnectionHeader = false;
			inTransferEncodingHeader = false;
=======
			gotConnectionHeader = false;
			gotTransferEncodingHeader = false;
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
			gotConnectionClose = false;
			gotConnectionKeepAlive = false;
			gotTransferEncodingChunked = false;
			gotUpgradeValue = false;
<<<<<<< HEAD
			contentLength = -1;
=======
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
			parser.OnMessageBegin(this);
		}
        
        action matched_absolute_uri {
            //Console.WriteLine("matched absolute_uri");
        }
        action matched_abs_path {
            //Console.WriteLine("matched abs_path");
        }
        action matched_authority {
            //Console.WriteLine("matched authority");
        }
        action matched_first_space {
            //Console.WriteLine("matched first space");
        }
        action leave_first_space {
            //Console.WriteLine("leave_first_space");
        }
        action eof_leave_first_space {
            //Console.WriteLine("eof_leave_first_space");
        }
		action matched_header { 
			//Console.WriteLine("matched header");
		}
		action matched_leading_crlf {
			//Console.WriteLine("matched_leading_crlf");
		}
		action matched_last_crlf_before_body {
			//Console.WriteLine("matched_last_crlf_before_body");
		}
		action matched_header_crlf {
			//Console.WriteLine("matched_header_crlf");
		}

		action on_method {
			parser.OnMethod(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(sb.ToString())));
		}

        action enter_method {
			Console.WriteLine("enter_method");
            mark = fpc;
        }
        
        action eof_leave_method {
            //Console.WriteLine("eof_leave_method fpc " + fpc + " mark " + mark);
            parser.OnMethod(this, new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_method {
            //Console.WriteLine("leave_method fpc " + fpc + " mark " + mark);
            parser.OnMethod(this, new ArraySegment<byte>(data, mark, fpc - mark));
        }
        
		action on_request_uri {
			parser.OnRequestUri(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(sb.ToString())));
		}

        action enter_request_uri {
            //Console.WriteLine("enter_request_uri fpc " + fpc);
            mark = fpc;
        }
        
        action eof_leave_request_uri {
            //Console.WriteLine("eof_leave_request_uri!! fpc " + fpc + " mark " + mark);
            parser.OnRequestUri(this, new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_request_uri {
            //Console.WriteLine("leave_request_uri fpc " + fpc + " mark " + mark);
            parser.OnRequestUri(this, new ArraySegment<byte>(data, mark, fpc - mark));
        }
        
		action on_query_string
		{
			parser.OnQueryString(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(sb2.ToString())));
		}

        action enter_query_string {
            //Console.WriteLine("enter_query_string fpc " + fpc);
            qsMark = fpc;
        }

        action leave_query_string {
            //Console.WriteLine("leave_query_string fpc " + fpc + " qsMark " + qsMark);
            parser.OnQueryString(this, new ArraySegment<byte>(data, qsMark, fpc - qsMark));
        }

		action on_fragment
		{
			parser.OnFragment(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(sb2.ToString())));
		}

        action enter_fragment {
            //Console.WriteLine("enter_fragment fpc " + fpc);
            fragMark = fpc;
        }

        action leave_fragment {
            //Console.WriteLine("leave_fragment fpc " + fpc + " fragMark " + fragMark);
            parser.OnFragment(this, new ArraySegment<byte>(data, fragMark, fpc - fragMark));
        }

        action version_major {
			versionMajor = (char)fc - '0';
		}

		action version_minor {
			versionMinor = (char)fc - '0';
		}
		
        action header_content_length {
            if (contentLength != -1) throw new Exception("Already got Content-Length. Possible attack?");
			//Console.WriteLine("Saw content length");
			contentLength = 0;
			inContentLengthHeader = true;
        }

		action header_connection {
			//Console.WriteLine("header_connection");
<<<<<<< HEAD
			inConnectionHeader = true;
=======
			gotConnectionHeader = true;
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
		}

		action header_connection_close {
			//Console.WriteLine("header_connection_close");
<<<<<<< HEAD
			if (inConnectionHeader)
=======
			if (gotConnectionHeader)
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
				gotConnectionClose = true;
		}

		action header_connection_keepalive {
			//Console.WriteLine("header_connection_keepalive");
<<<<<<< HEAD
			if (inConnectionHeader)
=======
			if (gotConnectionHeader)
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
				gotConnectionKeepAlive = true;
		}
		
		action header_transfer_encoding {
			//Console.WriteLine("Saw transfer encoding");
<<<<<<< HEAD
			inTransferEncodingHeader = true;
=======
			gotTransferEncodingHeader = true;
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
		}

		action header_transfer_encoding_chunked {
			if (inTransferEncodingHeader)
				gotTransferEncodingChunked = true;
		}

		action header_upgrade {
			inUpgradeHeader = true;
		}

		action on_header_name {
			parser.OnHeaderName(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(sb.ToString())));
		}

		action on_header_value {
			var str = sb.ToString();
			//Console.WriteLine("on_header_value '" + str + "'");
			//Console.WriteLine("inContentLengthHeader " + inContentLengthHeader);
			if (inContentLengthHeader)
				contentLength = int.Parse(str);

<<<<<<< HEAD
			inConnectionHeader = inTransferEncodingHeader = inContentLengthHeader = false;
			
			parser.OnHeaderValue(this, new ArraySegment<byte>(Encoding.ASCII.GetBytes(str)));
		}
=======
                contentLength *= 10;
                contentLength += (int)fc - (int)'0';
				//Console.WriteLine("Content length is looking like " + contentLength);
            }
        }
        
        action leave_header_value {
            //Console.WriteLine("leave_header_value fpc " + fpc + " fc " + (char)fc);
			var count = fpc - mark;
			if (count > 0 && gotUpgradeHeader)
				gotUpgradeValue = true;
            parser.OnHeaderValue(this, new ArraySegment<byte>(data, mark, count));
        }
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819

        action leave_headers {
			//Console.WriteLine("leave_headers contentLength = " + contentLength);
            parser.OnHeadersEnd(this);

			// if chunked transfer, ignore content length and parse chunked (but we can't yet so bail)
			// if content length given but zero, read next request
			// if content length is given and non-zero, we should read that many bytes
			// if content length is not given
			//   if should keep alive, assume next request is coming and read it
			//   else read body until EOF

			if (contentLength == 0)
			{
				parser.OnMessageEnd(this);
				fhold;
				fgoto main;
			}
			else if (contentLength > 0)
			{
				fhold;
				fgoto body_identity;
			}
			else
			{
				//Console.WriteLine("Request had no content length.");
				if (ShouldKeepAlive)
				{
					parser.OnMessageEnd(this);
					//Console.WriteLine("Should keep alive, will read next message.");
					fhold;
					fgoto main;
				}
				else
				{
					//Console.WriteLine("Not keeping alive, will read until eof. Will hold, but currently fpc = " + fpc);
					fhold;
					fgoto body_identity_eof;
				}
			}
        }

		action body_identity {
			var toRead = Math.Min(pe - p, contentLength);
<<<<<<< HEAD
			//Console.WriteLine("body_identity: reading " + toRead + " bytes from body.");
=======
			//Console.WriteLine("Reading " + toRead + " bytes from body.");
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
			if (toRead > 0)
			{
				parser.OnBody(this, new ArraySegment<byte>(data, p, toRead));
				p += toRead - 1;
				contentLength -= toRead;
				//Console.WriteLine("content length is now " + contentLength);

				if (contentLength == 0)
				{
					parser.OnMessageEnd(this);

					if (ShouldKeepAlive)
					{
						//Console.WriteLine("Transitioning from identity body to next message.");
						//fhold;
						fgoto main;
					}
					else
					{
						//fhold;
						fgoto dead;
					}
				}
				else
				{
					fbreak;
				}
			}
		}
		
<<<<<<< HEAD
		action body_identity_eof {
=======
		action eof_leave_body_identity_eof {
			//Console.WriteLine("eof_leave_body_identity_eof");
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
			var toRead = pe - p;
			//Console.WriteLine("body_identity_eof: reading " + toRead + " bytes from body.");
			if (toRead > 0)
			{
				parser.OnBody(this, new ArraySegment<byte>(data, p, toRead));
				p += toRead - 1;
				fbreak;
			}
			else
			{
				parser.OnMessageEnd(this);
				
				if (ShouldKeepAlive)
					fgoto main;
				else
				{
					//Console.WriteLine("body_identity_eof: going to dead");
					fhold;
					fgoto dead;
				}
			}
		}

		action enter_dead {
			throw new Exception("Parser is dead; there shouldn't be more data. Client is bogus? fpc =" + fpc);
		}

        include http "http.rl";
        
        }%%
        
        %% write data;
        
        public HttpParser(IHttpParserHandler parser)
        {
            this.parser = parser;
			sb = new StringBuilder();
            %% write init;
        }

        public int Execute(ArraySegment<byte> buf)
        {
            byte[] data = buf.Array;
            int p = buf.Offset;
            int pe = buf.Offset + buf.Count;
            int eof = buf.Count == 0 ? buf.Offset : -1;
            //int eof = pe;
            mark = 0;
            qsMark = 0;
            fragMark = 0;
            
			//if (p == pe)
			//	Console.WriteLine("Parser executing on p == pe (EOF)");

            %% write exec;
            
            var result = p - buf.Offset;

			if (result != buf.Count)
			{
				Console.WriteLine("error on character " + p);
				Console.WriteLine("('" + buf.Array[p] + "')");
				Console.WriteLine("('" + (char)buf.Array[p] + "')");
			}

			return p - buf.Offset;
        }
    }
}
using System;

namespace HttpSharp
{
    public interface IHttpRequestParser
    {
        void OnMethod(ArraySegment<byte> data);
        void OnRequestUri(ArraySegment<byte> data);
		void OnQueryString(ArraySegment<byte> data);
		void OnFragment(ArraySegment<byte> data);
		void OnVersionMajor(ArraySegment<byte> data);
		void OnVersionMinor(ArraySegment<byte> data);
        void OnHeaderName(ArraySegment<byte> data);
        void OnHeaderValue(ArraySegment<byte> data);
        void OnHeadersComplete();
    }

    public class HttpMachine
    {
        int cs;
        int mark;
		int qsMark;
		int fragMark;
        IHttpRequestParser parser;

        %%{

        # define actions
        machine http_parser;
		
		action matched_absolute_uri {
			Console.WriteLine("matched absolute_uri");
		}
		action matched_abs_path {
			Console.WriteLine("matched abs_path");
		}
		action matched_authority {
			Console.WriteLine("matched authority");
		}
		action matched_first_space {
			Console.WriteLine("matched first space");
		}

        action enter_method {
            mark = fpc;
        }
        
        action eof_leave_method {
			//Console.WriteLine("eof_leave_method fpc " + fpc + " mark " + mark);
            parser.OnMethod(new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_method {
			//Console.WriteLine("leave_method fpc " + fpc + " mark " + mark);
            parser.OnMethod(new ArraySegment<byte>(data, mark, fpc - mark));
        }
        
        action enter_request_uri {
			//Console.WriteLine("enter_request_uri fpc " + fpc);
            mark = fpc;
        }
        
        action eof_leave_request_uri {
			//Console.WriteLine("eof_leave_request_uri!! fpc " + fpc + " mark " + mark);
            parser.OnRequestUri(new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_request_uri {
			//Console.WriteLine("leave_request_uri fpc " + fpc + " mark " + mark);
            parser.OnRequestUri(new ArraySegment<byte>(data, mark, fpc - mark));
        }
		
        action enter_query_string {
			//Console.WriteLine("enter_query_string fpc " + fpc);
            qsMark = fpc;
        }

        action leave_query_string {
			//Console.WriteLine("leave_query_string fpc " + fpc + " qsMark " + qsMark);
            parser.OnQueryString(new ArraySegment<byte>(data, qsMark, fpc - qsMark));
        }
        action enter_fragment {
			//Console.WriteLine("enter_fragment fpc " + fpc);
            fragMark = fpc;
        }

        action leave_fragment {
			//Console.WriteLine("leave_fragment fpc " + fpc + " fragMark " + fragMark);
            parser.OnFragment(new ArraySegment<byte>(data, fragMark, fpc - fragMark));
        }
		
        action enter_version_major {
			//Console.WriteLine("enter_version_major fpc " + fpc);
            mark = fpc;
        }
        
        action eof_leave_version_major {
			//Console.WriteLine("eof_leave_version_major fpc " + fpc + " mark " + mark);
            parser.OnVersionMajor(new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_version_major {
			//Console.WriteLine("leave_version_major fpc " + fpc + " mark " + mark);
            parser.OnVersionMajor(new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action enter_version_minor {
			//Console.WriteLine("enter_request_uri fpc " + fpc);
            mark = fpc;
        }
        
        action eof_leave_version_minor {
			//Console.WriteLine("eof_leave_version_minor!! fpc " + fpc + " mark " + mark);
            parser.OnVersionMinor(new ArraySegment<byte>(data, mark, fpc - mark));
        }

        action leave_version_minor {
			//Console.WriteLine("leave_version_minor fpc " + fpc + " mark " + mark);
            parser.OnVersionMinor(new ArraySegment<byte>(data, mark, fpc - mark));
        }
        
        action enter_header_name {
			//Console.WriteLine("enter_header_name fpc " + fpc + " fc " + (char)fc);
            mark = fpc;
        }
        
        action leave_header_name {
			//Console.WriteLine("leave_header_name fpc " + fpc + " fc " + (char)fc);
            parser.OnHeaderName(new ArraySegment<byte>(data, mark, fpc - mark));
        }
        
        action enter_header_value {
			//Console.WriteLine("enter_header_value fpc " + fpc + " fc " + (char)fc);
            mark = fpc;
        }
        
        action leave_header_value {
			//Console.WriteLine("leave_header_value fpc " + fpc + " fc " + (char)fc);
            parser.OnHeaderValue(new ArraySegment<byte>(data, mark, fpc - mark));
        }

		action leave_headers {
			parser.OnHeadersComplete();
		}

        include http "http.rl";
        
        }%%
        
        %% write data;
        
        public HttpMachine(IHttpRequestParser parser)
        {
			this.parser = parser;
            %% write init;
        }

        public int Execute(ArraySegment<byte> buf)
        {
            byte[] data = buf.Array;
            int p = buf.Offset;
            int pe = buf.Offset + buf.Count;
            //int eof = pe == 0 ? 0 : -1;
			int eof = pe;
			mark = 0;
			qsMark = 0;
			fragMark = 0;
            
            %% write exec;
            
            return p - buf.Offset;
        }
    }
}
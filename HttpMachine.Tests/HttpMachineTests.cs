﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using HttpMachine;
using NUnit.Framework;
using System.Diagnostics;

// TODO
// parse request path
// allow ? in query
// extract transfer-encoding header, decode chunked encoding
// extract upgrade header, indicate upgrade
// line folding?

// error conditions
// - too-long method
// - fuzz

// not in scope (clients responsibility)
// 
// - too-long request uri
// - too-long headers
// - too-long body (or, will error out on next read)

namespace HttpMachine.Tests
{
    class Handler : IHttpParserHandler
    {
        public List<TestRequest> Requests = new List<TestRequest>();

        StringBuilder method, requestUri, queryString, fragment, headerName, headerValue;
        int versionMajor = -1, versionMinor = -1;
        Dictionary<string, string> headers;
        List<ArraySegment<byte>> body;
        bool onHeadersEndCalled, shouldKeepAlive;

        public void OnMessageBegin(HttpParser parser)
        {
            //Console.WriteLine("OnMessageBegin");

            // defer creation of buffers until message is created so 
            // NullRef will be thrown if OnMessageBegin is not called.

            method = new StringBuilder();
            requestUri = new StringBuilder();
            queryString = new StringBuilder();
            fragment = new StringBuilder();
            headerName = new StringBuilder();
            headerValue = new StringBuilder();
            headers = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);
            body = new List<ArraySegment<byte>>();
        }

        public void OnMessageEnd(HttpParser parser)
        {
            //Console.WriteLine("OnMessageEnd");

            Assert.AreEqual(shouldKeepAlive, parser.ShouldKeepAlive, 
                "Differing values for parser.ShouldKeepAlive between OnHeadersEnd and OnMessageEnd");
                
            TestRequest request = new TestRequest();
            request.VersionMajor = versionMajor;
            request.VersionMinor = versionMinor;
            request.ShouldKeepAlive = shouldKeepAlive;

            request.Method = method.ToString();
            request.RequestUri = requestUri.ToString();
            request.QueryString = queryString.ToString();
            request.Fragment = fragment.ToString();
            request.Headers = headers;
            request.OnHeadersEndCalled = onHeadersEndCalled;

            // aggregate body chunks into one big chunk
            var length = body.Aggregate(0, (s, b) => s + b.Count);
            if (length > 0)
            {
                request.Body = new byte[length];
                int where = 0;
                foreach (var buf in body)
                {
                    Buffer.BlockCopy(buf.Array, buf.Offset, request.Body, where, buf.Count);
                    where += buf.Count;
                }
            }
            // add it to the list of requests recieved.
            Requests.Add(request);

            // reset our internal state
            versionMajor = versionMinor = -1;
            method = requestUri = queryString = fragment = headerName = headerValue = null;
            headers = null;
            body = null;
            shouldKeepAlive = false;
            onHeadersEndCalled = false;
        }

        public void OnMethod(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnMethod: '" + str + "'");
            method.Append(str);
        }

        public void OnRequestUri(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnRequestUri:  '" + str + "'");
            requestUri.Append(str);
        }

        public void OnQueryString(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnQueryString:  '" + str + "'");
            queryString.Append(str);
        }

        public void OnFragment(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnFragment:  '" + str + "'");
            fragment.Append(str);
        }

        public void OnHeaderName(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnHeaderName:  '" + str + "'");

            if (headerValue.Length != 0)
                CommitHeader();

            headerName.Append(str);
        }

        public void OnHeaderValue(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnHeaderValue:  '" + str + "'");

            if (headerName.Length == 0)
                throw new Exception("Got header value without name.");

            headerValue.Append(str);
        }

        public void OnHeadersEnd(HttpParser parser)
        {
            //Console.WriteLine("OnHeadersEnd");
            onHeadersEndCalled = true;

            if (headerValue.Length != 0)
                CommitHeader();

            versionMajor = parser.MajorVersion;
            versionMinor = parser.MinorVersion;
            shouldKeepAlive = parser.ShouldKeepAlive;
        }

        void CommitHeader()
        {
            //Console.WriteLine("Committing header '" + headerName.ToString() + "' : '" + headerValue.ToString() + "'");
            headers[headerName.ToString()] = headerValue.ToString();
            headerName.Length = headerValue.Length = 0;
        }

        public void OnBody(HttpParser parser, ArraySegment<byte> data)
        {
            var str = Encoding.ASCII.GetString(data.Array, data.Offset, data.Count);
            //Console.WriteLine("OnBody:  '" + str + "'");
            body.Add(data);
        }
    }

    public class HttpParserTests
    {
        static void AssertRequest(TestRequest[] expected, TestRequest[] actual, HttpParser machine)
        {
            for (int i = 0; i < expected.Length; i++)
            {
                
                Assert.IsTrue(i <= actual.Length - 1, "Expected more requests than received");

                var expectedRequest = expected[i];
                var actualRequest = actual[i];
                //Console.WriteLine("Asserting request " + expectedRequest.Name);
                Assert.AreEqual(expectedRequest.Method, actualRequest.Method, "Unexpected method.");
                Assert.AreEqual(expectedRequest.RequestUri, actualRequest.RequestUri, "Unexpected request URI.");
                Assert.AreEqual(expectedRequest.VersionMajor, actualRequest.VersionMajor, "Unexpected major version.");
                Assert.AreEqual(expectedRequest.VersionMinor, actualRequest.VersionMinor, "Unexpected minor version.");
                Assert.AreEqual(expectedRequest.QueryString, actualRequest.QueryString, "Unexpected query string.");
                Assert.AreEqual(expectedRequest.Fragment, actualRequest.Fragment, "Unexpected fragment.");
                //Assert.AreEqual(expected.RequestPath, test.RequestPath, "Unexpected path.");

                Assert.IsTrue(actualRequest.OnHeadersEndCalled, "OnHeadersEnd was not called.");
                Assert.AreEqual(expectedRequest.ShouldKeepAlive, actualRequest.ShouldKeepAlive, "Wrong value for ShouldKeepAlive");

                foreach (var pair in expectedRequest.Headers)
                {
                    Assert.IsTrue(actualRequest.Headers.ContainsKey(pair.Key), "Actual headers did not contain key '" + pair.Key + "'");
                    Assert.AreEqual(pair.Value, actualRequest.Headers[pair.Key], "Actual headers had wrong value for key '" + pair.Key + "'");
                }

                foreach (var pair in actualRequest.Headers)
                {
                    Assert.IsTrue(expectedRequest.Headers.ContainsKey(pair.Key), "Unexpected header named '" + pair.Key + "'");
                }

                if (expectedRequest.Body != null)
                {
                    var expectedBody = Encoding.UTF8.GetString(expectedRequest.Body);
                    Assert.IsNotNull(actualRequest.Body, "Expected non-null request body");
                    var actualBody = Encoding.UTF8.GetString(actualRequest.Body);
                    Assert.AreEqual(expectedBody, actualBody, "Body differs");
                }
                else
                    Assert.IsNull(actualRequest.Body);
            }
        }

        [Test]
        public void SingleChunk()
        {
            // read each request as a single block and parse

            foreach (var request in TestRequest.Requests)
            {
                var handler = new Handler();
                var parser = new HttpParser(handler);
                Console.WriteLine("----- Testing request: '" + request.Name + "' -----");

                var parsed = parser.Execute(new ArraySegment<byte>(request.Raw));

                if (parsed != request.Raw.Length)
                    Assert.Fail("Error while parsing.");

                parser.Execute(default(ArraySegment<byte>));

                AssertRequest(new TestRequest[] { request }, handler.Requests.ToArray(), parser);
            }
        }

        [Test]
        public void RequestsSingle()
        {
            foreach (var request in TestRequest.Requests/*.Where(r => r.Name == "1.0 post")*/)
            {
                ThreeChunkScan(new TestRequest[] { request });
            }
        }

        [TestFixture]
        public class OneOhTests
        {
            [Test]
            public void PostKeepAlivePostEof()
            {
                PipelineAndScan("1.0 post keep-alive with content length", "1.0 post");
            }

            [Test]
            public void GetKeepAlivePostEof()
            {
                PipelineAndScan("1.0 get keep-alive", "1.0 post");
            }

            [Test]
            public void PostEof()
            {
                PipelineAndScan("1.0 post");
            }

            [Test]
            public void Get()
            {
                PipelineAndScan("1.0 get");
            }

            [Test]
            public void GetKeepAlive()
            {
                PipelineAndScan("1.0 get keep-alive");
            }

            [Test]
            public void PostKeepAliveGet()
            {
                PipelineAndScan("1.0 post keep-alive with content length", "1.0 get");
            }

            [Test]
            public void GetKeepAliveGet()
            {
                PipelineAndScan("1.0 get keep-alive", "1.0 get keep-alive", "1.0 get");
            }

            [Test]
            public void OneOhPostKeepAlivePost()
            {
                PipelineAndScan("1.0 post keep-alive with content length", "1.0 post");
            }

            [Test]
            public void GetKeepAlivePost()
            {
                PipelineAndScan("1.0 get keep-alive", "1.0 post");
            }
        }

        [TestFixture]
        public class OneOneTests
        {
            [Test]
            public void Get()
            {
                PipelineAndScan("1.1 get");
            }

            [Test]
            public void GetGet()
            {
                PipelineAndScan("1.1 get", "1.1 get");
            }

            [Test]
            public void GetGetGetClose()
            {
                PipelineAndScan("1.1 get", "1.1 get", "1.1 get close");
            }

            [Test]
            public void Post()
            {
                PipelineAndScan("1.1 post");
            }

            [Test]
            public void PostPost()
            {
                PipelineAndScan("1.1 post", "1.1 post");
            }

            [Test]
            public void PostPostPostClose()
            {
                PipelineAndScan("1.1 post", "1.1 post", "1.1 post close");
            }

            [Test]
            public void GetClose()
            {
                PipelineAndScan("1.1 get close");
            }

            [Test]
            public void PostClose()
            {
                PipelineAndScan("1.1 post close");
            }

            [Test]
            public void GetPost()
            {
                PipelineAndScan("1.1 get", "1.1 post");
            }

            [Test]
            public void GetPostClose()
            {
                PipelineAndScan("1.1 get", "1.1 post close");
            }

            [Test]
            public void GetPostGetClose()
            {
                PipelineAndScan("1.1 get", "1.1 post", "1.1 get close");
            }
        }

        static void PipelineAndScan(params string[] requests)
        {
<<<<<<< HEAD
            ThreeChunkScan(MakePipelined(requests));
=======
            ThreeChunkScan(TestRequest.Requests.Where(r => r.ShouldKeepAlive == true).Take(3));
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
        }

        static IEnumerable<TestRequest> MakePipelined(string[] requestNames)
        {
            List<TestRequest> result = new List<TestRequest>();
            foreach (var n in requestNames)
                result.Add(TestRequest.Requests.Where(r => r.Name == n).First());
            return result;
        }

        static void ThreeChunkScan(IEnumerable<TestRequest> requests)
        {
            // read each sequence of requests as three blocks, with the breaks in every possible combination.

            // one buffer to rule them all
            var raw = new byte[requests.Aggregate(0, (s, b) => s + b.Raw.Length)];
            int where = 0;
            foreach (var r in requests)
            {
                Buffer.BlockCopy(r.Raw, 0, raw, where, r.Raw.Length);
                where += r.Raw.Length;
            }

            int totalOperations = (raw.Length - 1) * (raw.Length - 2) / 2;
            int operationsCompleted = 0;
            byte[] buffer1 = new byte[80 * 1024];
            byte[] buffer2 = new byte[80 * 1024];
            byte[] buffer3 = new byte[80 * 1024];
            int buffer1Length = 0, buffer2Length = 0, buffer3Length = 0;

            Console.WriteLine("----- Testing requests: " +
                requests.Aggregate("", (s, r) => s + "; " + r.Name).TrimStart(';', ' ') +
                " (" + totalOperations + " ops) -----");

<<<<<<< HEAD
            int lastI = 0;
            int lastJ = 0;

            try
            {
                for (int j = 2; j < raw.Length; j++)
                    for (int i = 1; i < j; i++)
=======
            for (int j = 2; j < raw.Length; j++)
                for (int i = 1; i < j; i++)
                {
                    //Console.WriteLine();
                    if (operationsCompleted % 1000 == 0)
                        Console.WriteLine("  " + (100.0 * ((float)operationsCompleted / (float)totalOperations)));

                    operationsCompleted++;
                    //Console.WriteLine(operationsCompleted + " / " + totalOperations);

                    var handler = new Handler();
                    var parser = new HttpParser(handler);

                    var buffer1Length = i;
                    Buffer.BlockCopy(raw, 0, buffer1, 0, buffer1Length);
                    var buffer2Length = j - i;
                    Buffer.BlockCopy(raw, i, buffer2, 0, buffer2Length);
                    var buffer3Length = raw.Length - j;
                    Buffer.BlockCopy(raw, j, buffer3, 0, buffer3Length);

                    //Console.WriteLine("Parsing buffer 1.");
                    Assert.AreEqual(buffer1Length, parser.Execute(new ArraySegment<byte>(buffer1, 0, buffer1Length)), "Error parsing buffer 1.");

                    //Console.WriteLine("Parsing buffer 2.");
                    Assert.AreEqual(buffer2Length, parser.Execute(new ArraySegment<byte>(buffer2, 0, buffer2Length)), "Error parsing buffer 2.");

                    //Console.WriteLine("Parsing buffer 3.");
                    Assert.AreEqual(buffer3Length, parser.Execute(new ArraySegment<byte>(buffer3, 0, buffer3Length)), "Error parsing buffer 3.");

                    parser.Execute(default(ArraySegment<byte>));

                    try
>>>>>>> 81ad15800054bf746424984fbc30832f5bd56819
                    {
                        lastI = i; lastJ = j;
                        //Console.WriteLine();
                        if (operationsCompleted % 1000 == 0)
                            Console.WriteLine("  " + (100.0 * ((float)operationsCompleted / (float)totalOperations)));

                        operationsCompleted++;
                        //Console.WriteLine(operationsCompleted + " / " + totalOperations);

                        var handler = new Handler();
                        var parser = new HttpParser(handler);

                        buffer1Length = i;
                        Buffer.BlockCopy(raw, 0, buffer1, 0, buffer1Length);
                        buffer2Length = j - i;
                        Buffer.BlockCopy(raw, i, buffer2, 0, buffer2Length);
                        buffer3Length = raw.Length - j;
                        Buffer.BlockCopy(raw, j, buffer3, 0, buffer3Length);

                        //Console.WriteLine("Parsing buffer 1.");
                        Assert.AreEqual(buffer1Length, parser.Execute(new ArraySegment<byte>(buffer1, 0, buffer1Length)), "Error parsing buffer 1.");

                        //Console.WriteLine("Parsing buffer 2.");
                        Assert.AreEqual(buffer2Length, parser.Execute(new ArraySegment<byte>(buffer2, 0, buffer2Length)), "Error parsing buffer 2.");

                        //Console.WriteLine("Parsing buffer 3.");
                        Assert.AreEqual(buffer3Length, parser.Execute(new ArraySegment<byte>(buffer3, 0, buffer3Length)), "Error parsing buffer 3.");
                        
                        //Console.WriteLine("Parsing EOF");
                        Assert.AreEqual(parser.Execute(default(ArraySegment<byte>)), 0, "Error parsing EOF chunk.");
                        
                        AssertRequest(requests.ToArray(), handler.Requests.ToArray(), parser);
                    }
            }
            catch
            {
                Console.WriteLine("Problem while parsing chunks:");
                Console.WriteLine("---");
                Console.WriteLine(Encoding.UTF8.GetString(buffer1, 0, buffer1Length));
                Console.WriteLine("---");
                Console.WriteLine(Encoding.UTF8.GetString(buffer2, 0, buffer2Length));
                Console.WriteLine("---");
                Console.WriteLine(Encoding.UTF8.GetString(buffer3, 0, buffer3Length));
                Console.WriteLine("---");
                Console.WriteLine("Failed on i = " + lastI + " j = " + lastJ);
                throw;
            }
        }
    }
}

from libcpp.string cimport string

ctypedef Arg* ArgPtr


cdef extern from "re2/stringpiece.h" namespace "re2":
    cdef cppclass StringPiece:
        # Eliding some constructors on purpose.
        StringPiece(const char*) except +
        StringPiece(const string&) except +

        const char* data()
        int length()


cdef extern from "re2/re2.h" namespace "re2":

    cdef cppclass Arg "RE2::Arg":
        Arg()

    cdef cppclass RE2:
        RE2(const char*) except +

        @staticmethod
        bint PartialMatchN(
            const char *,
            const RE2&,
            const Arg* const args[],
            int,
        )

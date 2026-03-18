#include "stdafx.h"

#include "Utils.h"

#include <stdio.h>
#include <string>
#include <sys/time.h>

using namespace std;

namespace Utils
{
    uint64_t GetCurrentMilliSec()
    {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        return (tv.tv_sec) * 1000 + (tv.tv_usec) / 1000;
    }

    string ConvertSizeToShortSizeStr(uint64_t size, bool conv1KSmaller)
    {
        string strSize("");

        char buff[1024] = {0};

        int sizek = 1000;

        if(size > sizek)
        {
            double k_size = ((double)size) / sizek;
            if(k_size > sizek)
            {
                double m_size = k_size / sizek;
                if(m_size > sizek)
                {
                    double g_size = m_size / sizek;
                    snprintf(buff, 1024, "%.2f GB", g_size);
                }
                else
                {
                    snprintf(buff, 1024, "%.2f MB", m_size);
                }
            }
            else
            {
                snprintf(buff, 1024, "%.2f KB", k_size);
            }
        }
        else if(conv1KSmaller)
        {
            snprintf(buff, 1024, "%.2f B", (double)size);
        }

        strSize = buff;

        return strSize;
    }

}


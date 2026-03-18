#ifndef _GLOBAL_H_
#define _GLOBAL_H_

#include <stdint.h>

#include <list>
#include <vector>

#define WINAPI

#include "Common/strhelper.h"

class UIBridgeBase;

struct ResultData;

typedef std::vector<sunjwbase::tstring> TStrVector;
typedef std::vector<uint64_t> ULLongVector;
typedef std::list<ResultData> ResultList;

#define MAX_FILES_NUM 8192

enum ResultState
{
    RESULT_NONE = 0,
    RESULT_PATH,
    RESULT_META,
    RESULT_ALL,
    RESULT_ERROR
};

struct ResultData
{
    ResultState enumState;
    sunjwbase::tstring tstrPath;
    uint64_t ulSize;
    sunjwbase::tstring tstrMDate;
    sunjwbase::tstring tstrVersion;
    sunjwbase::tstring tstrMD5;
    sunjwbase::tstring tstrSHA256;
    sunjwbase::tstring tstrError;
};

struct ThreadData
{
    UIBridgeBase *uiBridge;

    bool threadWorking;
    bool stop;

    bool uppercase;
    uint64_t totalSize;

    uint32_t nFiles;
    TStrVector fullPaths;

    ResultList resultList;
};

#endif

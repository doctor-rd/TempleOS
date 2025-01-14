#help_index "Compiler;Cmd Line (Typically)"

I64 Cmp(U8 *filename,U8 *map_name=NULL,U8 *out_name=NULL,U8 mapfile_drv_let=0)
{//AOT Compile HC or PRJ file a and output BIN file. Returns err_cnt.
  U8 *ptr,*fbuf=NULL,*fbuf2=NULL,*fbuf3=NULL,
	*patch_table=MAlloc(0x20000);
  CAOT *tmpaot;
  I64 i,cnt,size=0,error_cnt=0,warning_cnt=0,aot_U8s=0;
  CBinFile *bfh;
  CAOTImportExport *tmpie,*tmpie1;
  CAOTAbsAddr *tmpa,*tmpa1;
  CAOTHeapGlblRef *tmphgr,*tmphgr1;
  CAOTHeapGlbl *tmphg,*tmphg1;

  fbuf=ExtDft(filename,"PRJ.Z");
  fbuf2=MStrPrint("#include \"%s\"",fbuf);
  if (map_name)
    fbuf3=ExtDft(map_name,"MAP.Z");

  if (tmpaot=CmpBuf(fbuf2,fbuf3,&error_cnt,&warning_cnt,mapfile_drv_let)) {
    aot_U8s=tmpaot->aot_U8s;
    ptr=patch_table;
//See $LK,"Load",A="MN:Load"$()
    cnt=0;
    tmpa=tmpaot->abss;
    while (tmpa) {
      if (!(tmpa->type&IEF_IMM_NOT_REL))
	cnt++;
      tmpa=tmpa->next;
    }
    if (cnt) {
      *ptr++=IET_ABS_ADDR;
      *ptr(U32 *)++=cnt;
      *ptr++=0;
      tmpa=tmpaot->abss;
      while (tmpa) {
	tmpa1=tmpa->next;
	if (!(tmpa->type&IEF_IMM_NOT_REL))
	  *ptr(U32 *)++ =tmpa->rip;
	Free(tmpa);
	tmpa=tmpa1;
      }
    }
    tmphg=tmpaot->heap_glbls;
    while (tmphg) {
      tmphg1=tmphg->next;
      cnt=0;
      tmphgr=tmphg->references;
      while (tmphgr) {
	cnt++;
	tmphgr=tmphgr->next;
      }
      if (cnt) {
	*ptr++=IET_DATA_HEAP;
	*ptr(U32 *)++=cnt;
	if (tmphg->str) {
	  i=StrLen(tmphg->str);
	  MemCpy(ptr,tmphg->str,i+1);
	  Free(tmphg->str);
	  ptr+=i+1;
	} else
	  *ptr++=0;
	*ptr(I64 *)++=tmphg->size;
	tmphgr=tmphg->references;
	while (tmphgr) {
	  tmphgr1=tmphgr->next;
	  *ptr(U32 *)++=tmphgr->rip;
	  Free(tmphgr);
	  tmphgr=tmphgr1;
	}
      }
      Free(tmphg);
      tmphg=tmphg1;
    }

    //Do exports first
    tmpie=tmpaot->next_ie;
    while (tmpie!=&tmpaot->next_ie) {
      tmpie1=tmpie->next;
      if (!tmpie->type || IET_REL32_EXPORT<=tmpie->type<=IET_IMM64_EXPORT) {
	QueRem(tmpie);
	*ptr++=tmpie->type;
	*ptr(U32 *)++=tmpie->rip;
	if (tmpie->str) {
	  i=StrLen(tmpie->str);
	  MemCpy(ptr,tmpie->str,i+1);
	  Free(tmpie->str);
	  ptr+=i+1;
	} else
	  *ptr++=0;
	Free(tmpie->src_link);
	Free(tmpie);
      }
      tmpie=tmpie1;
    }

    //Do imports second
    tmpie=tmpaot->next_ie;
    while (tmpie!=&tmpaot->next_ie) {
      tmpie1=tmpie->next;
      QueRem(tmpie);
      *ptr++=tmpie->type;
      if (tmpie->aot)
	tmpie->rip+=tmpie->aot->rip2;
      *ptr(U32 *)++=tmpie->rip;
      if (tmpie->str) {
	i=StrLen(tmpie->str);
	MemCpy(ptr,tmpie->str,i+1);
	Free(tmpie->str);
	ptr+=i+1;
      } else
	*ptr++=0;
      Free(tmpie->src_link);
      Free(tmpie);
      tmpie=tmpie1;
    }

    *ptr++=IET_END;
    MemSet(ptr,0,16);
    i=ptr-patch_table;
//Needs 16 ALIGN
    size=(sizeof(CBinFile)+aot_U8s+i+15)&-16;
    bfh=MAlloc(size);
    bfh->jmp=0xEB+256*(sizeof(CBinFile)-2);
#assert sizeof(CBinFile)-2<=I8_MAX
    bfh->reserved=0;
    bfh->bin_signature=BIN_SIGNATURE_VAL;
    bfh->org=tmpaot->org;
    bfh->module_align_bits=tmpaot->max_align_bits;
    bfh->patch_table_offset=sizeof(CBinFile)+aot_U8s;
    bfh->file_size=size;
    MemCpy(bfh(U8 *)+sizeof(CBinFile),tmpaot->buf,aot_U8s);
    MemCpy(bfh(U8 *)+sizeof(CBinFile)+aot_U8s,patch_table,
	  size-aot_U8s-sizeof(CBinFile));
    Free(fbuf2);
    if (out_name)
      fbuf2=ExtDft(out_name,"BIN.Z");
    else
      fbuf2=ExtChg(fbuf,"BIN.Z");
    FileWrite(fbuf2,bfh,size);
    Free(bfh);
    Free(tmpaot->buf);
    QueDel(tmpaot);
    Free(tmpaot);
  }
  Free(patch_table);
  Free(fbuf);
  Free(fbuf2);
  Free(fbuf3);
  Print("Errs:%d Warns:%d Code:%X Size:%X\n",
	error_cnt,warning_cnt,aot_U8s,size);
  return error_cnt;
}

I64 RunFile(U8 *name,I64 ccf_flags=0,...)
{//$LK,"ExeFile",A="MN:ExeFile"$() with args using $LK,"LastFun",A="MN:LastFun"$().
  ExeFile(name,ccf_flags);
  return LastFun(argc,argv);
}

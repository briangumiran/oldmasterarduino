
/*
//  GSMoff();
 }
 */

#define GSMUARTBUFFLEN 500
#define MSGLEN 250f
#define OFF 1  // stat pin is HIGH (1) so it needs to be turn off
#define ON  0  // stat pin is LOW (0) so it needs to be turn on
#define CLEAR 1  // clear gsmUartBuffer after query
#define SAVE  0  // save gsmUartBuffer after query
#define STATPIN 6
#define PWONPIN 7
#define RESETARDUINO asm volatile("jmp 0x0000");

// char *gsmUartBuffer = NULL;    // string where gsm responses are stored

void PowerGSM(char mode){
  pinMode(PWONPIN, OUTPUT);
  pinMode(STATPIN, INPUT);

  Serial.print("\n\nTurning GSM ");
  if (mode == OFF) Serial.print("OFF.. ");
  else Serial.print("ON.. ");  

  if(((digitalRead(STATPIN) == 1) && (mode == ON)) || ((digitalRead(STATPIN) == 0) && (mode == OFF))){
    digitalWrite(PWONPIN, LOW);
    delay(1000);
    // pull down powerKey low for one second
    digitalWrite(PWONPIN, HIGH);
    delay(1000);
    // pull back powerKey up
    digitalWrite(PWONPIN, LOW);
    delay(5000);
    Serial.println("toggled GSM");
    digitalWrite(PWONPIN, LOW);
    delay(1000);
    // pull down powerKey low for one second
    digitalWrite(PWONPIN, HIGH);
    delay(1000);
    // pull back powerKey up
    digitalWrite(PWONPIN, LOW);
    delay(1000);
  }
  // do not power on if stat pin is already high
  else{//(digitalRead(STATPIN) == mode){
    Serial.print("Activating power on switch...");
    // make sure powerKey is high (common emitter switch)
    digitalWrite(PWONPIN, LOW);
    delay(1000);
    // pull down powerKey low for one second
    digitalWrite(PWONPIN, HIGH);
    delay(1000);
    // pull back powerKey up
    digitalWrite(PWONPIN, LOW);
    // wait for STATPIN to go high
    unsigned long timestart = millis();
    unsigned long timenow = millis();
    while(digitalRead(STATPIN) == mode){
      if( timenow - timestart > 7000 ){
        time_conf();
        Serial.print("Entering sleep mode...");
        sleepNow();	
        Serial.println(" done");
        delay(3000);
      }
      timenow = millis();
    }  

  }
  Serial.println("done");
  
}


/*
  void SendATcmd(char *atCmd);
 Sends command atCmd to UART2 and waits for reply 'OK' string
 */
//char gsmUartBuffer[50];
char *SendATcmd(char *atCmd, char *gsmUartBuffer, char *sndFlg){

  int timeout = 0;
  char let = 'a';
  unsigned int j = 0; 
  char *stat = NULL;
  short r = 0;
  sndFlg[0]= '1';
  sndFlg[1]= '\0';
  
  Serial.print(atCmd);
  Serial2.flush();
  
  // allocate memory for GSM responses
  // gsmUartBuffer = (char *) calloc(GSMUARTBUFFLEN, sizeof(char *));
  Serial2.write(atCmd);
  delay(100);
  
  while(stat == NULL && timeout < 15){
    
    while(r<80){//121413 - increased from 50 to 80. Code does not finish
      
      while(Serial2.available()){
        gsmUartBuffer[j] = (char)Serial2.read();
        //Serial.print(gsmUartBuffer[j]);
        j++;
      }
      
      gsmUartBuffer[j] = '\0';
      stat = strstr(gsmUartBuffer, "OK");
      if (stat)  break;
      else {
        stat = strstr(gsmUartBuffer, "ERROR");
        if (stat) break;
      }
      
      delay(100);
      r++;
    }
    
    stat = strstr(gsmUartBuffer, "OK");
    
    if (stat)  break;
    else {
        stat = strstr(gsmUartBuffer, "ERROR");
        if (stat) break;
        else{
          Serial.write(":");
        }
    }
 
    timeout++;
    delay(100);
  }

  if (stat == NULL){
    sndFlg[0]= '0';
    sndFlg[1]= '\0';
  }

  if (timeout >= 15){
    Serial.print("Error: GSM unresponsive ");
    Serial.print("Cmd: ");
    Serial.println(atCmd);
  }
  else if (strstr(gsmUartBuffer, "ERROR")){
    Serial.print("GSM returned ERROR for AT command: "); 
    Serial.println(atCmd);
  }
  else {
    //Serial.print(gsmUartBuffer);
    Serial.println("->OK");
  }

}

/*
  Fill up csq variable from gsm reply
 i.e.
 
 AT+CSQ
 CSQ: mm,99
 OK
 
 where mm can range from 01 to 30 if signal is poor to good
 or 99 if signal is non existent
 
 Important note: csq must be freed by calling function
 */
 
int simAvailable(char *gsmUartBuffer, char *sndFlg)
{
  short i=0, j=0;
  int sim = 0;
  //sndFlg="0";
  //sim = (char *) calloc(1, sizeof(char *));
  SendATcmd("AT+CSMINS?\r\n", gsmUartBuffer, sndFlg);
 // Serial.print("SendFlag value is");
  //Serial.println(sndFlg);  
  
  if(strstr(gsmUartBuffer,",")){
    for(i=0; gsmUartBuffer[i]!=','; i++);    
    if(gsmUartBuffer[i+1] == '0') return 0;
    else return 1;
  }
  else{
    return 0;
  }
 // Serial.println(sim); 
}


void GetCSQ(char *csq, char *gsmUartBuffer, char *sndFlg)
{
  short i=0, j=0;
  int digitFlg = 1;
  SendATcmd("AT+CSQ\r\n", gsmUartBuffer, sndFlg);      
  
  if(strstr(gsmUartBuffer,",")){
    //  find first digit character token
    for(i=0; !isdigit(gsmUartBuffer[i]); i++){
      if(i > 100){
        digitFlg = 0;
        break;
      }
    }
    
    if(digitFlg == 1){
      //  store next chars until ',' is encoutered
      for (j=0; gsmUartBuffer[i]!=','; i++,j++){
        csq[j] = gsmUartBuffer[i];
        csq[j+1] = '\0';   
      }
    }
    else{
      csq[0] = '0';      csq[1] = '\0'; 
      //csq="0";
    }
  }
  else{
    csq[0] = '0';    csq[1] = '\0';
    //csq="0";
  }
  clearString(gsmUartBuffer); 
  //free(gsmUartBuffer);
}



/*
  Initialize SIM900D module
 */
void InitGSM(){
  //char *csq = NULL;  
  char *temp = NULL;
  int timeInSec = 0;

  temp = (char *) calloc(40, sizeof(char *));

  PowerGSM(ON);
  delay(5000);

  WDT_off();
  WDT_Prescaler_Change();
  WDTCSR = 0xFF;
  SendATcmd("AT\r\n",temp, sndFlg);
  
  delay(200);
  WDT_off();

  WDT_off();
  WDT_Prescaler_Change();
  WDTCSR = 0xFF;
  SendATcmd("ATE0\r\n", temp, sndFlg);  

  delay(200);
  WDT_off();
  
  WDT_off();
  WDT_Prescaler_Change();
  WDTCSR = 0xFF;
  SendATcmd("AT+CMGF=1\r\n", temp, sndFlg);  
  delay(200);
  WDT_off();
  
  Serial.println("Successful Initialization"); 
  free(temp);
}

/*
  SIM900D sending message procedure
 */
int SendMsg(char *number, char *msg, char *gsmUartBuffer){
  char *numstr = NULL;
  char ctrlZ = 0x1A;
  char *OKstat = NULL;
  char *ERRORstat = NULL;
  short retries = 5;
  short r=0, s=0, t=0, j=0;
  int okFlag=1;

  numstr = (char *) calloc(100, sizeof(char *));
  // gsmUartBuffer = (char *) calloc(GSMUARTBUFFLEN, sizeof(char *));
  sprintf(numstr, "AT+CMGS=\"%s\"\r\n",number);
  Serial.print("\nMsg: ");
  Serial.println(msg);
  Serial.print("Num: ");
  Serial.println(number);

//  for(s=0; s<10 && !OKstat; s++){
    // for stubborn gsms that die with no particular reason
    //if (digitalRead(STATPIN) == OFF) InitGSM();

    Serial2.println(numstr);

    for(r=0; r<50; r++){
      delay(100);
      if (Serial2.available()){
        if (Serial2.read() == '>'){
          Serial.print('>');
          break;
        }
      }
      else{
        Serial.print(":");
        delay(1000);
      }
    }

    if(r==50) {
      Serial.println("Error: GSM not responding to AT+CMGS=<number>\\r\\n");
      delay(3000);
      okFlag=1;
    }

    Serial2.print(msg);
    Serial2.print(ctrlZ);

    for(t=0, j=0; t<6; t++){
      delay(2000);
      if(Serial2.available()){

        while(Serial2.available()){
          gsmUartBuffer[j] = Serial2.read();
          j++; 
          gsmUartBuffer[j] = '\0';
        }

        OKstat = strstr(gsmUartBuffer, "OK");
        if(OKstat){
          Serial.println("Message sent.");
          okFlag=0;
          break; 
        }
        
        ERRORstat = strstr(gsmUartBuffer, "ERROR");
        if(ERRORstat){
          Serial.println("Message sending failed.");
          break;
        }
      }
      else{
        Serial.print(".");
      }
    }

    if(t==6) {
      Serial.println("Error: Message sending failed after six times");
      //PowerGSM(OFF);
      delay(3000);
      okFlag=1;
     }
  //////////////// forloop }

  if (!OKstat){
    Serial.println("Aborting message sending.");
    okFlag=1;

  }
  clearString(numstr);
  free(numstr);
  return okFlag;
}

void CheckSimMessages(boolean deleteMsg)
{
  // char * msg = NULL;
  // char * i = NULL;
  // char *stat, *ptr1, *ptr2 = NULL;
  // char *temp2 = NULL;
  // char *deletemsg = NULL;
  // char *messages = NULL;
  // unsigned char msgno = 0x00;
  // char *msgnostr = NULL;

  // msgnostr = (char *) calloc(2, sizeof(char *));
  // temp2 = (char *) calloc(50, sizeof(char *));
  // deletemsg = (char *) calloc(20, sizeof(char *));
  // messages = (char *) calloc(300, sizeof(char *));

  // for (msgno = 0x01; msgno < 0x1F; msgno++){
  // sprintf(temp2, "AT+CMGR=%d\r\n",msgno);
  // SendATcmd(temp2, messages);
  // Serial.print(messages);
  // }

  // free(deletemsg);
  // free(temp2);
  // free(msgnostr);
  // free(messages);
}

struct __freelist
{
  size_t sz;
  struct __freelist *nx;
};

extern struct __freelist *__flp;
extern uint8_t* __brkval;

void fix28135_malloc_bug()
{
  for (__freelist *fp = __flp, *lfp = 0; fp; fp = fp->nx)
  {
    if (((uint8_t*)fp + fp->sz + 2) == __brkval)
    {
      __brkval = (uint8_t*)fp;
      if (lfp)
        lfp->nx = 0;
      else
        __flp = 0;
      break;
    }
    lfp = fp;
  }
}


int GetTimestampTag(char *Timetag, char *filename)
{
  char *ptr = NULL;
  char *temp = NULL;
  char *clockStr = NULL;

  char year[3];
  char month[3];
  char day[3];
  char hour[3];
  char minutes[3];

  int timeInSec = 0;
  int minute_int;
  int second_int;

  temp = (char *) calloc(10, sizeof(char *));
  clockStr = (char *) calloc(50, sizeof(char *));

  SendATcmd("AT+CCLK?\r\n", clockStr, sndFlg);      
  Serial.print(clockStr);

  ptr = strchr(clockStr, '"');
  ptr += 1;
  strncpy(temp, ptr, 2);
  sprintf(year, "%s", temp);

  ptr += 3;
  strncpy(temp, ptr, 2);
  sprintf(month, "%s", temp);

  ptr += 3;
  strncpy(temp, ptr, 2);
  sprintf(day, "%s", temp);

  ptr = strchr(clockStr, ',');
  ptr += 1;
  strncpy(temp, ptr, 2);
  sprintf(hour, "%s", temp);

  ptr += 3;
  strncpy(temp, ptr, 2);
  sprintf(minutes, "%s", temp);
  minute_int = atoi(temp);

  ptr += 3;
  strncpy(temp, ptr, 2);
  second_int = atoi(temp);

  timeInSec = minute_int*60 + second_int;

  /*
    string:    +CCLK: "yy/MM/dd,hh:mm:ss"
   index                         i12345
   */

  // format for MMC
  sprintf(Timetag, "%s%s%s%s%s", year, month, day, hour, minutes);
  sprintf(logfile, "%s%s%s", year, month, day);
  //Serial.println(Timetag);

  clearString(clockStr);
  clearString(temp);
  free(clockStr);
  free(temp);

  return timeInSec;
}


int okToSend(int *simC, char *csqC, char *buffer, char *sndFlg ){
  
  *simC = simAvailable(buffer, sndFlg);
  Serial.print("->CSMINS: ");
  Serial.println(*simC);
  
  if (sndFlg[0] == '0') return 0;
  
  GetCSQ(csqC, buffer, sndFlg);    //Hindi ba dapat after to magcheck ng unang sndFlg
  
  //Serial.print("Orig->CSQ: ");
  //Serial.println(csqC);
  
  //csqC[0]='9';csqC[1]='9';
  //csqC="99";
  //csqC[0] = '0';//csqC[1] = '\0'; 
  //csqC="0\0";
  //csqC="0";//this will work. dapat wala ung '\0'
  Serial.print("->CSQ: ");
  Serial.println(csqC);
  /*
  if(csqC=="0") Serial.println("zero daw sya");
  if(csqC=="99") Serial.println("99 daw ako");
  else Serial.println("failed match");
  
  Serial.print("first: ");
  Serial.println(!simCheck || *simC != 0);
  Serial.print("second: ");
  Serial.println(!signalCheck || (csqC == "99"));
  Serial.print("third: ");
  Serial.println(sndFlg[0] != '0');
  */
  if( (!simCheck || *simC != 0) && (!signalCheck || (csqC != "99" && "0")) && (sndFlg[0] != '0') ) return 1;
  else return 0;
  
}

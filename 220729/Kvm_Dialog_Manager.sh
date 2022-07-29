#!/bin/bash
# 변수 선언
temp=$(mktemp -t test.XXX)      # 함수내에서 결과를 파일로 저장하기위해
ans=$(mktemp -t test.XXX)       # 메뉴에서 선택한 번호담기위한 변수
image=$(mktemp -t test.XXX)     # 템플릿 이미지를 담기위한 변수
vmname=$(mktemp -t test.XXX)    # 가상머신 이름 담기위한 변수
flavor=$(mktemp -t test.XXX)    # CPU/RAM 세트인 flavor 정보 담기위한 변수
dellist=$(mktemp -t del.XXX)    # 가상 머신 리스트를 radio 에 전달하기 위해 변환한 Data 를 담은 변수
delinstance=$(mktemp -t del.XXX) #삭제할 인스턴스 번호를 담은 변수
# 함수 선언
# 가상머신 리스트 출력 함수
vmlist(){
        virsh list --all > $temp
        dialog --textbox $temp 20 50
}

# 가상 네트워크 리스트 출력 함수
vmnetlist(){
        virsh net-list --all > $temp
        dialog --textbox $temp 20 50
}
# 가상머신 삭제
vmdel(){
        echo "" > $dellist
        vmlist=$(virsh list --all | grep -v Name | gawk {'print $2'})
        #radio 에 사용할 리스트 제작
        count=$[ 0 + 1 ]
        for vmne in $vmlist
        do
                if [ $count == 1 ]
                then
                echo "${vmne} '${vmne}인스턴스' ON " >> $dellist
                else
                echo "${vmne} '${vmne}인스턴스' OFF " >> $dellist
                fi
                count=$(($count + 1))
        done
	 dialoglist=$(cat $dellist)

        #삭제 리스트 출력 메뉴

        dialog --title "가상머신 삭제" --radiolist "삭제할 인스턴스 선택" 15 50 0 $dialoglist 2>$delinstance
 
	if [ $? -eq 0 ]
	then

 	vmdelin=$(cat $delinstance)


	#삭제 여부 확인

	dialog --title "삭제 여부" --yesno " ${vmdelin} 인스턴스를 삭제하시겠습니까?" 10 40

		#삭제 진행
		if [ $? -eq 0 ]
		then
			virsh destroy ${vmdelin}
			virsh undefine ${vmdelin} --remove-all-storage
			if [ $? -eq 0 ]
			then
			dialog --msgbox "삭제 완료" 10 20
			fi
		fi
	fi	
}

# 가상머신 생성 함수
vmcreation(){
	#이미지 선택
        dialog --title "이미지 선택" --radiolist " 베이스 이미지 선택" 15 50 5 "CentOS7" "센토스 7 베이스 이미지" ON "Ubuntu" "우분투 베이스 이미지" OFF "RHEL" "레드햇 엔터프라이브 리눅스" OFF 2>$image

	vmimage=$(cat $image)
	case $vmimage in
	CentOS7)
		os=/cloud/CentOS7-Base.qcow2 ;;
	Ubuntu)
		os=/cloud/Ubuntu2-Base.qcow2 ;;
	RHEL)
		os=/cloud/RHEL-Base.qcow2 ;;
	*)
		dialog --msgbox "잘못된 선택입니다" 10 40 ;;
	esac

	#os 선택이 정상 처리라면 인스턴스 이름 입력하기로 이동
	if [ $? -eq 0 ]
	then
		dialog --title "인스턴스 이름" --inputbox "인스턴스의 이름을 입력하세요 : " 10 50 2>$vmname
		
		#선택된 이름을 이용하여 새로운 볼륨 생성
		name=$(cat $vmname)
		cp $os /cloud/${name}.qcow2
		#종료 코드가 0 인 경우 다음 실행 - flavor
		if [ $? -eq 0 ]
		then
			dialog --title "스펙 선택" --radiolist "필요한 자원을 선택하세요" 15 50 5 "m1.small"  "가상 cpu 1개, 메모리 1GM" ON "m1.medium" "가상 cpu 2개, 메모리 2GB" OFF "m1.large" "가상 cpu 4개, 메모리 8GB " OFF 2> $flavor
		
		#flavor 에 따라 변수에 자원 개수 입력
		spec=$(cat $flavor)
		case $spec in
		m1.small)
			vcpus="1"
			ram="1024"
			dialog --msgbox "CPU:${vcpus}core(s) RAM:${ram}MB" 10 50  ;;
		m1.medium)
			vcpus="1"
                        ram="2048"
                        dialog --msgbox "CPU:${vcpus}core(s) RAM:${ram}MB" 10 50  ;;
		m1.large)
			vcpus="2"
                        ram="8192"
                        dialog --msgbox "CPU:${vcpus}core(s) RAM:${ram}MB" 10 50  ;;
		esac
		
			#설치 진행
			if [ $? -eq 0 ]
			then
				virt-install --name $name --vcpus $vcpus --ram $ram --disk /cloud/${name}.qcow2 --import --network network:default,model=virtio --os-type linux --os-variant rhel7.0 --noautoconsole > /dev/null
			
			fi
			dialog --msgbox " 설치가 완료되었습니다" 10 50
			
		fi
	fi
	
}

# 메인코드
while [ 1 ]
do
        # 메인메뉴 출력하기
        dialog --menu "KVM 관리 시스템" 20 40 8 1 "가상머신 리스트" 2 "가상 네트워크 리스트" 3 "가상머신 생성" 4 "가상머신 삭제" 0 "종료" 2> $ans

        # 종료코드 확인하여 cancel 이면 프로그램 종료
        if [ $? -eq 1 ]
        then
                break
        fi

        selection=$(cat $ans)
        case $selection in
        1)
                vmlist ;;
        2)
                vmnetlist ;;
        3)
                vmcreation ;;
	4)
		vmdel ;;
        0)
                break ;;
        *)
                dialog --msgbox "잘못된 번호 선택됨" 10 40
        esac
done

# 종료전 임시파일 삭제하기
rm -rf $temp 2> /dev/null
rm -rf $ans 2> /dev/null
rm -rf $image 2> /dev/null
rm -rf $vmnet 2> /dev/null
rm -rf $flavor 2> /dev/null
rm -rf $dellist 2> /dev/null
rm -rf $delinstance 2> /dev/null
